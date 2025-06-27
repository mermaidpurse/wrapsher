require 'parslet'
require 'wrapsher'
require 'pry'

module Wrapsher
  class Node
    class MetaField < Node
    end

    class Version < Node
    end

    class Type < Node
    end

    class VarRef < Node
      def initialize(slice, filename: '-')
        @filename = filename
        @name = slice.to_s
        @line = slice.line_and_column[0]
      end

      def to_s
        "\"${_wshv_#{@name}}\""
      end
    end

    class Module < Node
      def initialize(slice, filename: '-')
        @filename = filename
        @name = slice.to_s
        @line = slice.line_and_column[0]
      end

      def to_s
        <<~EOF
        # module #{@name}
        _wshv_#{@name}='module/#{@name}:#{@filename}'
        _wsh_line='#{@filename}:#{@line}'
        EOF
      end
    end

    class FunStatement < Node
      attr_reader :line

      def initialize(slice, filename: '-')
        @filename = filename
        @signature = Signature.new(slice[:signature], filename: @filename)
        @line = @signature.line
        @body = Body.new(slice[:body], filename: @filename)
      end

      def to_s
        <<~EOF
        # #{@signature.type} #{@signature.name}(#{@signature.arg_definitions&.map(&:to_s).join(', ')})
        #{@signature.function_name(:presence)}=1
        #{@signature.function_name(:definition)}() {
          _wsh_error='error:'; _wsh_result='null:'; _wsh_line='#{@filename}:#{@line}'
          #{@signature.argument_binding}

          #{@body.to_s}
          #{@signature.check_return}
        }
        EOF
      end
    end

    class Signature < Node
      attr_reader :type, :name, :arg_definitions, :line

      def initialize(slice, filename: '-')
        @filename = filename
        @line = slice[:type].line_and_column[0]
        @type = slice[:type].to_s
        @name = slice[:name].to_s
        if !slice[:arg_definitions].nil?
          arg_definitions = slice[:arg_definitions].is_a?(Array) ? slice[:arg_definitions] : [slice[:arg_definitions]]
          @arg_definitions = arg_definitions.map { |arg| ArgDefinition.new(arg, filename: @filename) }
        else
          @arg_definitions = []
        end
        @line = slice[:type].line_and_column[0]
      end

      def argument_binding
        @arg_definitions.map.with_index do |arg, i|
          # It's actually a variable binding, complete with evaluation, so this
          # actually isn't right.
          [
            "_wsh_line='#{@filename}:#{arg.line}'",
            "_wshv_#{arg.name}=\"${_wsh_arg#{i}}\"",
            "unset _wsh_arg#{i}",
            "_wsh_check \"${_wshv_#{arg.name}}\" '#{arg.type}' '#{arg.name}' || return 1",
          ].join("\n  ")
        end.join("\n  ")
      end

      def check_return
        "_wsh_check \"${_wsh_result}\" '#{type}' '#{name}()' || return 1"
      end

      def function_name(nametype = :definition)
        prefix = nametype == :presence ? '_wshp' : '_wshf'
        if @arg_definitions.empty?
          "#{prefix}_#{@name}"
        else
          "#{prefix}_#{@name}_#{@arg_definitions[0].type_with_underscore}"
        end
      end
    end

    class ArgDefinition < Node
      attr_reader :name, :type, :line
      def initialize(slice, filename: '-')
        @filename = filename
        @line = slice[:type].line_and_column[0]
        @name = slice[:name].to_s
        @type = slice[:type].to_s
      end

      def type_with_underscore
        @type.gsub(/[^a-zA-Z0-9_]/, '_')
      end

      def to_s
        "#{@type} #{@name}"
      end
    end

    class Body < Node
      def initialize(slice, filename: '-')
        @filename = filename
        @node = Node.from_obj(slice, filename: @filename)
      end

      # TODO :This is where we keep track of variables and unset them at the end.
      def to_s
        @node.to_s
      end
    end

    class FunCall < Node
      def initialize(slice, filename: '-')
        @filename = filename
        @function_name = slice[:name].to_s
        @line = slice[:name].line_and_column[0]
        @function_args = [slice[:fun_args]].flatten.compact.map do |arg|
          Node.from_obj(arg, filename: @filename)
        end
      end

      def function_dispatch
        if @function_args.empty?
          "  _wsh_dispatch '#{@function_name}' || return 1"
        else
          "  _wsh_dispatch '#{@function_name}' \"${_wsh_arg0}\" || return 1"
        end
      end

      def to_s
        call_bindings = @function_args.map.with_index do |arg, i|
          # TODO: this is more like a term? test
          if arg.is_a? FunCall
            <<~EOF
            #{arg.to_s}
            _wsh_arg@#{i}="${_wsh_result}"
            EOF
          else
            "_wsh_arg#{i}=#{arg.to_s}"
          end
        end
        <<~EOF
          #{call_bindings.join("\n  ")}
          #{function_dispatch}
        EOF
      end
    end

    class StringTerm < Node
      def initialize(slice, filename: '-')
        @filename = filename
        string_type = slice.keys.first
        case string_type
        when :single_quoted
          @value = slice[string_type].to_s
          @line = slice[string_type].line_and_column[0]
        else
          raise "Unknown string type: #{string_type}"
        end
        @term = true
      end

      def to_s
        "'string:#{@value}'"
      end
    end

    class UseModule < Node
      def initialize(slice, filename: '-')
        @filename = filename
        @module_name = slice.to_s
        @line = slice.line_and_column[0]
      end

      def module_code
        File.read("./examples/modules/#{@module_name}.sh")
      end

      def to_s
        <<~EOF
        # use module #{@module_name}
        _wsh_line='#{@filename}:#{@line}'
        #{module_code}
        _wsh_line='#{@filename}:#{@line}'
        EOF
      end
    end

    def initialize(slice, filename: '-')
      @filename = filename
      @slice = slice
      @term = false
    end

    def to_s
      raise NotImplementedError, "Subclasses must implement a to_s method"
    end

    attr_reader :filename

    @@nodes = {
      module: Module,
      meta_field: MetaField,
      version: Version,
      type: Type,
      fun_call: FunCall,
      fun_statement: FunStatement,
      string_term: StringTerm,
      use_module: UseModule,
      var_ref: VarRef,
    }.freeze

    def term?
      @term || false
    end

    def initialize(slice, filename: '-')
      @filename = filename
    end

    class << self
      def from_obj(obj, filename: nil)
        type = obj.keys.first
        if @@nodes.key?(type)
          @@nodes[type].new(obj[type], filename: filename)
        else
          raise "Unknown node type: #{type}"
        end
      end
    end
  end
end
