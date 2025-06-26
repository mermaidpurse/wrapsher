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
    end

    class Module < Node
      def initialize(slice)
        @name = slice.to_s
        @line = slice.line_and_column[0]
      end

      def to_s
        <<~EOF
        # module #{@name}
        __wsh_module_name='#{@name}'
        __wsh_line='#{@filename}:#{@line}'
        EOF
      end
    end

    # I really got to think about function dispatch. Maybe I should build
    # up a table here, by signature, if the receiver is just a syntactic sugar
    # for the first argument.
    # io.printf('hello') -> printf(io, 'hello') -> printf_module_io('string:hello') ?
    # Maybe io shoudl be a variable that's bound to a type. And every module is a
    # type. type io module. type vector array.
    # magnitude(vector v) -> 'magnitude:vector'
    # printf(type io, string s) -> 'printf:io:string'
    # add(int a, int b) -> 'add:int:int'
    class FunStatement < Node
      def initialize(slice)
        @signature = Signature.new(slice[:signature])
        @body = Body.new(slice[:body])
      end

      def to_s
        <<~EOF
        # #{@signature.type} #{@signature.name}(#{@signature.arg_definitions&.map(&:to_s).join(', ')})
        #{@signature.function_name}() {
          __wsh_error='null:'
          __wsh_result='null:'
          #{@signature.argument_binding}
          #{@body.to_s}
          #{@signature.unset_bindings}
        }
        EOF
      end
    end

    class Signature < Node
      attr_reader :type, :name, :arg_definitions

      def initialize(slice)
        @type = slice[:type].to_s
        @name = slice[:name].to_s
        @arg_definitions = slice[:arg_definitions]&.map { |arg| ArgDefinition.new(arg) } || []
        @line = slice[:type].line_and_column[0]
      end

      def argument_binding
        @arg_definitions.map.with_index do |arg, i|
          # It's actually a variable binding, complete with evaluation, so this
          # actually isn't right.
          "__wsh_var_#{arg.name} = \"__wsh_arg#{i}\""
        end.join("\n  ")
      end

      def unset_bindings
        @arg_definitions.map.with_index do |arg, i|
          "unset __wsh_arg#{i}"
        end.join("\n  ")
      end

      # Probable needs module
      def function_name
        "__wsh_#{@type}_#{@name}"
      end
    end

    class Body < Node
      def initialize(slice)
        @node = Node.from_obj(slice)
      end

      def to_s
        @node.to_s
      end
    end

    class FunCall < Node
      def initialize(slice)
        @function_name = slice[:name].to_s
        @line = slice[:name].line_and_column[0]
        # This definitely isn't right. It should be done by the parser/transforms.
        @function_args = ([receiver] + slice.except(:name).map { |key, arg| Node.from_obj({ key => arg }) }).compact
      end

      def receiver
        parts = @function_name.split('.')
        parts.length > 1 ? parts[0] : nil
      end

      def function_name
        # This should be done by the parser
        parts = @function_name.split('.')
        name = parts.length > 1 ? parts[-1] : @function_name
        "  __wsh_#{name}"
      end

      def to_s
        call_bindings = @function_args.map.with_index do |arg, i|
          if arg.is_a? FunCall
            <<~EOF
            #{arg.to_s}
            __wsh_arg@#{i}="${__wsh_result}"
            EOF
          else
            "__wsh_arg#{i}='#{arg.to_s}'"
          end
        end
        <<~EOF
        #{call_bindings.join("\n  ")}
        #{function_name}
        #{call_bindings.length.times.map { |i| "  unset __wsh_arg#{i}" }.join("\n")}
        EOF
      end
    end

    class StringTerm < Node
      def initialize(slice)
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
        "string:#{@value}"
      end
    end

    class UseModule < Node
      def initialize(slice)
        @module_name = slice.to_s
        @line = slice.line_and_column[0]
      end

      def module_code
        File.read("./examples/modules/#{@module_name}.sh")
      end

      def to_s
        <<~EOF
        # use module #{@module_name}
        __wsh_line='#{@filename}:#{@line}'
        #{module_code}
        __wsh_line='#{@filename}:#{@line}'
        EOF
      end
    end

    def initialize(slice)
      @slice = slice
      @term = false
    end

    def to_s
      raise NotImplementedError, "Subclasses must implement a to_s method"
    end

    attr_accessor :filename

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

    class << self
      def from_obj(obj, filename: nil)
        type = obj.keys.first
        if @@nodes.key?(type)
          node = @@nodes[type].new(obj[type])
          node.filename = filename
          node
        else
          raise "Unknown node type: #{type}"
        end
      end
    end
  end
end
