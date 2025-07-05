require 'parslet'
require 'wrapsher'
require 'pry'

module Wrapsher

  WSH_INCLUDE_PATH = [
    "${ENV['WSH_HOME']}/wsh",
    './wsh',
  ].freeze

  class Node

    class Assignment < Node
      def initialize(slice, tables:)
        super
        @line = slice[:var].line_and_column[0]
        @name = slice[:var].to_s
        @rvalue = Node.from_obj(slice[:rvalue], tables: tables)
      end

      def to_s
        [
          line,
          @rvalue.to_s,
          tables.globals[@name] ? "_wshg_#{@name}=\"${_wsh_result}\"" : "_wsh_set_local #{@name} \"${_wsh_result}\""
        ].join("\n"  )
      end
    end

    class BoolTerm < Node
      def initialize(slice, tables:)
        super
        @value = slice.to_s
      end

      def to_s
        [
          line,
          "_wsh_result='bool:#{@value}'"
        ].join("\n  ")
      end
    end

    class Conditional < Node
      def initialize(slice, tables:)
        super
        @line = slice[:keyword_if].line_and_column[0] if slice[:keyword_if].respond_to?(:line_and_column)
        @else_line = slice[:keyword_else].line_and_column[0] if slice[:keyword_else] && slice[:keyword_else].respond_to?(:line_and_column)
        @condition = Node.from_obj(slice[:condition], tables: tables)
        @then_body = Body.new(slice[:then], tables: tables)
        @else_body = Body.new(slice[:else], tables: tables) if slice[:else]
      end

      def to_s
        code = []
        code << line
        code << @condition.to_s
        code << line
        code << "_wsh_assert \"${_wsh_result}\" 'bool' 'if condition' || return 1"
        code << 'case "${_wsh_result}" in bool:true)'
        code << @then_body.to_s
        code << ';;'
        if @else_body
          code << '*)'
          code << line
          code << @else_body.to_s
          code << ';;'
        end
        code << 'esac'
        code.join("\n  ")
      end
    end

    class MetaField < Node
    end

    class Version < Node
    end

    class Type < Node
      def initialize(slice, tables:)
        super
        @name = slice[:name].to_s
        @store_type = slice[:store_type].to_s if slice[:store_type]
        raise "error:redefinition of global variable #{@name} at #{@filename}:#{@line}" if tables.globals.key?(@name)

        tables.globals[@name] = true
      end

      def to_s
        code = []
        code << line
        code << "# type #{@name}"
        code << "_wsh_set_global #{@name} 'type/#{@name}:#{@store_type}'"
        code.join("\n")
      end
    end

    class Module < Node
      def initialize(slice, tables:)
        super
        @name = slice.to_s
        if tables.globals[@name]
          raise "error:Module global name #{@name} conflicts with existing global variable at #{@filename}:#{line}"
        end

        tables.globals[@name] = true
      end

      def to_s
        [
          "# module #{@name}",
          "_wsh_set_global #{@name} 'module/#{@name}:#{@filename}'",
          line
        ].join("\n")
      end
    end

    class IntTerm < Node
      def initialize(slice, tables:)
        super
        @value = slice.to_s
      end

      def to_s
        [
          line,
          "_wsh_result='int:#{@value}'"
        ].join("\n  ")
      end
    end

    class FunStatement < Node
      attr_reader :signature

      def initialize(slice, tables:)
        super
        @signature = Signature.new(slice[:signature], tables: tables)
        @line = @signature.line
        @body = Body.new(slice[:body], tables: tables)
        tables.functions[@signature.name] ||= {}
        tables.functions[@signature.name][@signature.dispatch_type] = @signature
      end

      def to_s
        [
          "# #{@signature.summary}",
          "#{@signature.function_name(:presence)}=1",
          "#{@signature.function_name(:definition)}() {",
          "  _wsh_error='error:'; _wsh_result='null:'; _wsh_line='#{@filename}:#{@line}'",
          "  : $((_wsh_frame++))",
          "  _wsh_set_local _reflist reflist:",
          "  #{@signature.argument_binding}",
          "  # function body",
          "  #{@body.to_s}",
          "  # end function body",
          "  #{@signature.check_return}",
          "  : $((_wsh_frame--))",
          "}"
        ].join("\n")
      end
    end

    class Signature < Node
      attr_reader :type, :name, :arg_definitions

      def initialize(slice, tables:)
        super
        @line = slice[:type].line_and_column[0]
        @type = slice[:type].to_s
        @name = slice[:name].to_s
        if !slice[:arg_definitions].nil?
          arg_definitions = slice[:arg_definitions].is_a?(Array) ? slice[:arg_definitions] : [slice[:arg_definitions]]
          @arg_definitions = arg_definitions.map { |arg| ArgDefinition.new(arg, tables: tables) }
        else
          @arg_definitions = []
        end
        @line = slice[:type].line_and_column[0]
      end

      def summary
        "#{type} #{name}(#{arg_definitions&.map(&:to_s).join(', ')})"
      end

      def arity
        @arg_definitions.length
      end

      def nullary?
        arity == 0
      end

      def nary?
        arity > 0
      end

      def dispatch_type
        nullary? ? :nullary : arg_definitions[0].type
      end

      def argument_binding
        @arg_definitions.map do |arg|
          [
            line,
            "_wsh_stack_peek_into _wshi",
            "_wsh_assert \"${_wshi}\" '#{arg.type}' '#{arg.name}' || return 1",
            "_wsh_stack_pop_into \"_wshv_${_wsh_frame}_#{arg.name}\"",
          ].join("\n  ")
        end.join("\n  ")
      end

      def check_return
        "_wsh_assert \"${_wsh_result}\" '#{type}' '#{name}()' || return 1"
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
      attr_reader :name, :type

      def initialize(slice, tables:)
        super
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
      def initialize(slice, tables:)
        super
        slices = slice.is_a?(Array) ? slice : [slice]
        @nodes = slices.map { |sl| Node.from_obj(sl, tables: tables) }
      end

      # TODO: This is where we keep track of variables and unset them at the end.
      def to_s
        code = []
        @nodes.each do |node|
          code << node.to_s
        end
        code.join("\n  ")
      end
    end

    class FunCall < Node
      def initialize(slice, tables:)
        super
        @function_name = slice[:name].to_s
        @line = slice[:name].line_and_column[0] if slice[:name].respond_to?(:line_and_column)
        @function_args = [slice[:fun_args]].flatten.compact.map do |arg|
          Node.from_obj(arg, tables: tables)
        end
      end

      # Need to establish new stack frame and do ref bookkeeping and 
      # variable cleanup
      def function_dispatch
        code = []
        code << line
        if @function_args.empty?
          code << "_wsh_dispatch_nullary '#{@function_name}' || return 1"
        else
          code << "_wsh_dispatch '#{@function_name}' || return 1"
        end
        code.join("\n  ")
      end

      def to_s
        call_bindings = @function_args.reverse.map do |arg|
          [
            arg.to_s,
            "_wsh_stack_push \"${_wsh_result}\""
          ].join("\n  ")
        end
        [
          call_bindings.join("\n  "),
          function_dispatch
        ].join("\n")
      end
    end

    class ShellCode < Node
      def initialize(slice, tables:)
        super
        @shellcode = StringValue.new(slice, tables: tables)
      end

      def to_s
        @shellcode.to_s
      end
    end

    class StringValue < Node
      attr_reader :value

      def initialize(slice, tables:)
        super
        @string_type = slice.keys.first
        @value = slice[@string_type].to_s
      end

      def to_s
        @value
      end
    end

    class StringTerm < Node
      attr_reader :value

      def initialize(slice, tables:)
        super
        @value = StringValue.new(slice, tables: tables)
      end

      def to_s
        [
          line,
          "_wsh_result='string:#{@value}'"
        ].join("\n  ")
      end
    end

    class UseExternal < Node
      def initialize(slice, tables:)
        super
        @external_command = slice.to_s
        tables.external[@external_command] = true
        @line = slice.line_and_column[0]
      end

      def to_s
        [
          "# use external command #{@external_command}",
          line,
          "# _wsh_check_external '#{@external_command}' || return 1"
        ].join("\n")
      end
    end

    class UseGlobal < Node
      def initialize(slice, tables:)
        super
        @line = slice[:name].line_and_column[0]
        @global_name = slice[:name].to_s
        @initial_value = Node.from_obj(slice[:value], tables: tables)
        tables.globals[@global_name] = true
      end

      def to_s
        [
          "# use global #{@global_name}",
          @initial_value.to_s,
          line,
          "_wsh_set_global '#{@global_name}' \"${_wsh_result}\""
        ].join("\n")
      end
    end

    class UseModule < Node
      attr_accessor :included

      def initialize(slice, tables:)
        super
        @module_name = slice.to_s
        @line = slice.line_and_column[0]
        @included_nodes = include
      end

      def include
        return if tables.included[@module_name]

        WSH_INCLUDE_PATH.flat_map do |loc|
          module_filename = "#{loc}/#{@module_name}.wsh"
          if File.exist?(module_filename)
            tables.included[@module_name] = true
            saved_filename = tables.filename # TODO: yuck
            tables.filename = module_filename
            module_ast = Wrapsher::Parser.new.parse(module_filename)
            compiled_nodes = [module_ast].flatten.map do |obj|
              Node.from_obj(obj, tables: tables)
            end
            tables.filename = saved_filename
            return compiled_nodes
          end
        end
        raise "Module #{@module_name} not found in include paths: #{WSH_INCLUDE_PATH.join(', ')}"
      end

      def to_s
        [
          "# use module #{@module_name} from #{@filename}:#{@line}",
          @included_nodes.map(&:to_s).join("\n")
        ].compact.map(&:to_s).join("\n")
      end
    end

    # Maybe this should be a FunCall
    class VarRef < Node
      def initialize(slice, tables:)
        super
        @name = slice.to_s
      end

      def to_s
        [
          line,
          tables.globals[@name] ? "_wsh_result=\"${_wshg_#{@name}}\"" : "_wsh_get_local '#{@name}' _wsh_result"
        ].join("\n  ")
      end
    end

    def initialize(slice, tables:)
      binding.pry unless tables.respond_to? :filename
      @filename = tables.filename
      @tables = tables
      @slice = slice
      @line = slice.line_and_column[0] if slice.respond_to? :line_and_column
    end

    def line
      @line ? "_wsh_line='#{@filename}:#{@line}'" : ''
    end

    def to_s
      raise NotImplementedError, "Subclasses(#{self.class}) must implement a to_s method: #{self.inspect}"
    end

    attr_reader :filename, :tables

    @@nodes = {
      assignment: Assignment,
      bool_term: BoolTerm,
      conditional: Conditional,
      module: Module,
      meta_field: MetaField,
      version: Version,
      type: Type,
      fun_call: FunCall,
      fun_statement: FunStatement,
      int_term: IntTerm,
      shellcode: ShellCode,
      string_term: StringTerm,
      use_external: UseExternal,
      use_global: UseGlobal,
      use_module: UseModule,
      var_ref: VarRef,
    }.freeze

    class << self
      def from_obj(obj, tables:)
        PP.pp(obj, $stderr) unless obj.respond_to?(:keys)
        type = obj.keys.first
        raise "Unknown node type: #{type}" unless @@nodes.key?(type)

        @@nodes[type].new(obj[type], tables: tables)
      end
    end
  end
end
