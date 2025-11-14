# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2025 Mermaidpurse

require 'parslet'
require 'wrapsher'
require 'pry'

module Wrapsher
  # Base class for Wrapsher language nodes
  class Node
    # var = expression
    class Assignment < Node
      def initialize(slice, tables:)
        super
        @line = slice[:var].line_and_column[0] if slice[:var].respond_to?(:line_and_column)
        @name = slice[:var].to_s

        @rvalue = Node.from_obj(slice[:rvalue], tables: tables)
        if tables.context
          # We're in a function context, so we're keeping track of locals we create
          tables.log("In context '#{tables.context&.summary}' - Adding local variable #{@name}")
          tables.push_local(@name)
        else
          tables.log("Skipping local variable #{@name}, not in a function context")
        end
      end

      def errors
        @rvalue.errors
      end

      def to_s
        [
          @rvalue.to_s,
          tables.globals[@name] ? "_wshg_#{@name}=\"${_wsh_result}\"" : "_wsh_set_local #{@name} \"${_wsh_result}\""
        ].join("\n  ")
      end
    end

    # true | false
    class BoolTerm < Node
      def initialize(slice, tables:)
        super
        @value = slice.to_s
      end

      def to_s
        [
          "_wsh_result='bool:#{@value}'"
        ].join("\n  ")
      end
    end

    # break
    class Break < Node
      def initialize(slice, tables:)
        super
        return if tables.state.key?(:in_loop) && tables.state[:in_loop].positive?

        raise Wrapsher::CompilationError, "Must use 'break' inside a loop at #{@filename}:#{@line}"
      end

      def to_s
        [
          'break # break'
        ].join("\n  ")
      end
    end

    # TODO: Needs to get smarter
    # Probably all these methods should return an array of lines
    # So it can be truly empty if needed.
    class Comment < Node
      def to_s
        ''
      end
    end

    # conditional expression
    class Conditional < Node
      def initialize(slice, tables:)
        super
        @line = slice[:keyword_if].line_and_column[0] if slice[:keyword_if].respond_to?(:line_and_column)
        @else_line = slice[:keyword_else].line_and_column[0] if slice[:keyword_else].respond_to?(:line_and_column)
        @condition = Node.from_obj(slice[:condition], tables: tables)
        @then_body = Body.new(slice[:then], tables: tables)
        @else_body = Body.new(slice[:else], tables: tables) if slice[:else]
      end

      def errors
        [
          @condition.errors,
          @then_body.errors,
          @else_body&.errors
        ]
      end

      def to_s
        code = []
        code << @condition.to_s
        code << "_wsh_assert \"${_wsh_result}\" 'bool' 'if condition' || break"
        code << 'case "${_wsh_result}" in bool:true)'
        code << @then_body.to_s
        code << ';;'
        if @else_body
          code << '*)'
          code << @else_body.to_s
          code << ';;'
        end
        code << 'esac'
        code.join("\n  ")
      end
    end

    # continue
    class Continue < Node
      def initialize(slice, tables:)
        super
        return if tables.state.key?(:in_loop) && tables.state[:in_loop].positive?

        raise Wrapsher::CompilationError, "Must use 'continue' inside a loop at #{@filename}:#{@line}"
      end

      def to_s
        [
          'continue # continue'
        ].join("\n  ")
      end
    end

    # [:]
    class EmptyMapTerm < Node
      def initialize(slice, tables:)
        super
        @inner = Node.from_obj(inner_ast, tables: tables)
        @inner.line = @line
      end

      def inner_ast
        {
          fun_call: {
            name: 'new',
            fun_args: [{ var_ref: 'map' }]
          }
        }
      end

      def to_s
        @inner.to_s
      end
    end

    # <function>(...)
    class FunCall < Node
      def initialize(slice, tables:)
        super
        @function_name = slice[:name].to_s
        @no_check = slice[:no_check] if slice.key?(:no_check)
        @line = slice[:name].line_and_column[0] if slice[:name].respond_to?(:line_and_column)
        @function_args = [slice[:fun_args]].flatten.compact.map do |arg|
          Node.from_obj(arg, tables: tables)
        end
      end

      def errors
        e = []
        e << ["No such function '#{@function_name}' at #{filename}:#{@line}"] unless tables.functions.key?(@function_name)
        if @function_args.empty? && !tables.functions[@function_name].key?(:nullary)
          e << ["No nullary function '#{@function_name}()' at #{filename}:#{line}"]
        end
        # We can't actually check for the right arity functions which accept an argument
        # because we don't (yet) know the type of the first argument.
        e << @function_args.map(&:errors)
      end

      def function_dispatch
        code = []
        code << "_wsh_prof_event B wsh '#{@function_name}'" if tables.options[:profile]
        code << "_wsh_dispatch '#{@function_name}' '#{@function_args.length}'"
        code << "_wsh_prof_event E wsh '#{@function_name}'" if tables.options[:profile]
        code << "_wsh_check_return \"in #{@function_name} at #{@filename}:#{@line}\" || break"
        code.join("\n  ")
      end

      def to_s
        call_bindings = @function_args.reverse.map do |arg|
          [
            arg.to_s,
            '_wsh_stack_push "${_wsh_result}" "#{@filename}:#{@line}"'
          ].join("\n  ")
        end
        [
          call_bindings.join("\n  "),
          function_dispatch
        ].join("\n")
      end
    end

    # <type> <function>(...) { }
    class FunStatement < Node
      attr_reader :signature

      # rubocop:disable Metrics/AbcSize
      def initialize(slice, tables:)
        super
        @signature = Signature.new(slice[:signature], tables: tables)
        @line = @signature.line
        tables.log("Entering context '#{@signature.summary}'")
        tables.context = @signature
        # Argument binding introduces locals into the context
        @signature.arg_definitions.each do |arg|
          tables.push_local(arg.name)
        end
        # Since we have set a context, any assignments that
        # occur in the body will add to locals
        @body = Body.new(slice[:body], tables: tables)
        tables.log("Exiting context '#{@signature.summary}'")
        tables.context = nil
        @locals = tables.locals.dup
        tables.log("Found locals: #{@locals.inspect}; clearing (outside of context)")
        tables.clear_locals!
        tables.functions[@signature.name] ||= {}
        if tables.functions[@signature.name][@signature.dispatch_type]
          previous = tables.functions[@signature.name][@signature.dispatch_type]
          raise Wrapsher::CompilationError, "redefinition of #{previous.summary} at #{@filename}:#{@line}"
        end
        tables.functions[@signature.name][@signature.dispatch_type] = @signature
      end
      # rubocop:enable Metrics/AbcSize

      def errors
        @body.errors
      end

      def cleanup_locals
        'unset ' + @locals.map { |v| "\"_wshv_${_wsh_frame}_#{v}\"" }.join(' ')
      end

      def to_s
        [
          "# #{@signature.summary}",
          "#{@signature.function_name(:presence)}=1",
          "#{@signature.function_name(:definition)}() {",
          "_wsh_result='bool:false'; _wsh_error=''",
          'while :; do',
          '  :',
          "  #{@signature.argument_binding}",
          '  # function body',
          "  #{@body}",
          "  #{cleanup_locals}",
          '  # end function body',
          '  break',
          'done',
          'case "${_wsh_error}" in ?*) return 1 ;; esac',
          @signature.check_return.to_s,
          '}'
        ].join("\n")
      end
    end

    # <type> <function>(...)
    class Signature < Node
      attr_accessor :name
      attr_reader :type, :arg_definitions

      # rubocop:disable Metrics/AbcSize
      def initialize(slice, tables:)
        super
        @line = slice[:type].line_and_column[0] if slice[:type].respond_to?(:line_and_column)
        @type = slice[:type].to_s
        @name = slice[:name].to_s if slice.key?(:name)
        if !slice[:arg_definitions].nil?
          arg_definitions = slice[:arg_definitions].is_a?(Array) ? slice[:arg_definitions] : [slice[:arg_definitions]]
          @arg_definitions = arg_definitions.map { |arg| ArgDefinition.new(arg, tables: tables) }
        else
          @arg_definitions = []
        end
        @line = slice[:type].line_and_column[0] if slice[:type].respond_to?(:line_and_column)
      end
      # rubocop:enable Metrics/AbcSize

      def summary(use_name = nil)
        "#{type} #{use_name || name}(#{arg_definitions&.map(&:to_s)&.join(', ')})"
      end

      def arity
        @arg_definitions.length
      end

      def nullary?
        arity.zero?
      end

      def nary?
        arity.positive?
      end

      def dispatch_type
        nullary? ? :nullary : arg_definitions[0].type
      end

      def argument_binding
        @arg_definitions.map do |arg|
          [
            '_wsh_stack_peek_into _wshi',
            "_wsh_assert \"${_wshi}\" '#{arg.type}' '#{arg.name}' '#{@filename}:#{@line}' || break",
            "_wsh_stack_pop_into \"_wshv_${_wsh_frame}_#{arg.name}\""
          ].join("\n  ")
        end.join("\n  ")
      end

      def check_return(use_name = nil)
        "_wsh_assert \"${_wsh_result}\" '#{type}' '#{use_name || name}()'"
      end

      def function_name(nametype = :definition)
        prefix = nametype == :presence ? '_wshp' : '_wshf'
        if @arg_definitions.empty?
          "#{prefix}_#{@name}_0"
        else
          "#{prefix}_#{@name}_#{@arg_definitions.length}_#{@arg_definitions[0].type_with_underscore}"
        end
      end
    end

    # argument definitions
    class ArgDefinition < Node
      attr_reader :name, :type

      def initialize(slice, tables:)
        super
        @line = slice[:type].line_and_column[0] if slice[:type].respond_to?(:line_and_column)
        @name = slice[:name].to_s
        @type = slice[:type].to_s
      end

      def type_with_underscore
        @type.gsub(/[^a-zA-Z0-9_]/, '__')
      end

      def to_s
        "#{@type} #{@name}"
      end
    end

    # function and block bodies
    class Body < Node
      def initialize(slice, tables:)
        super
        slices = slice.is_a?(Array) ? slice : [slice]
        @nodes = slices.map { |sl| Node.from_obj(sl, tables: tables) }
      end

      def errors
        @nodes.map(&:errors)
      end

      def to_s
        code = []
        @nodes.each do |node|
          code << node.to_s
        end
        code.join("\n  ")
      end
    end

    # int constants
    class IntTerm < Node
      def initialize(slice, tables:)
        super
        @value = slice.to_s
      end

      def to_s
        [
          "_wsh_result='int:#{@value}'"
        ].join("\n  ")
      end
    end

    # list and map terms, constant or not
    # TODO: detect if list or map is all
    # constants and inline them if so
    class ListTerm < Node
      def initialize(slice, tables:)
        super
        @line = slice[:lbracket].line_and_column[0] if slice[:lbracket].respond_to?(:line_and_column)
        @elements = if slice[:elements].nil?
                      []
                    elsif slice[:elements].is_a?(Array)
                      slice[:elements]
                    else
                      [slice[:elements]]
                    end
        new_node = {
          fun_call: {
            name: 'new',
            fun_args: [{ var_ref: 'list' }]
          }
        }
        @inner_ast = if @elements.empty?
                       new_node
                     else
                       list = push_elements(new_node, @elements)
                       if @all_pairs
                         make_map(list)
                       else
                         list
                       end
                     end
        @inner = Node.from_obj(@inner_ast, tables: tables)
        @inner.line = @line
      end

      def make_map(list)
        {
          fun_call: {
            name: 'from_pairlist',
            fun_args: [
              { var_ref: 'map' },
              list
            ]
          }
        }
      end

      def push_elements(list_node, elements)
        @all_pairs = true
        elements.reduce(list_node) do |acc, el|
          @all_pairs = false unless pair?(el)
          {
            fun_call: {
              name: 'push',
              fun_args: [acc, el]
            }
          }
        end
      end

      def pair?(element)
        element&.keys&.first == :pair
      end

      def to_s
        @inner.to_s
      end
    end

    # - Create a unique type for the lambda that has
    #   a storage type of `map`. The value of the anonymous
    #   function contains a map which is the context: the
    #   local variables that were captured in the closure.
    # - The any call(fun f) function in the core module
    #   strips the fun+ from
    # rubocop:disable Metrics/ClassLength
    class Lambda < Node
      attr_reader :signature, :refid, :closure

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def initialize(slice, tables:)
        super
        @signature = slice[:signature]
        @line = @signature[:type].line_and_column[0] if @signature[:type].respond_to?(:line_and_column)
        @refid = tables.refid
        @signature[:arg_definitions] = [@signature[:arg_definitions]].compact.flatten
        @signature[:name] = 'with'
        @signature[:arg_definitions].unshift({
                                               name: '_wsh_context',
                                               type: "_fun#{@refid}"
                                             })
        summary = "#{@signature[:name]}(" + @signature[:arg_definitions].map { |arg|
                                              "#{arg[:type]} #{arg[:name]}"
                                            }.join(', ') + ')'
        tables.log("Creating lambda #{@refid} with signature: #{summary}, capturing #{tables.locals.inspect}")
        variable_capture = tables.locals.reduce({
                                                  fun_call: {
                                                    name: 'new',
                                                    fun_args: [{ var_ref: 'map' }]
                                                  }
                                                }) do |arg, var|
          {
            fun_call: {
              name: 'push',
              fun_args: [
                arg,
                {
                  fun_call: {
                    name: 'from_kv',
                    fun_args: [
                      { var_ref: 'pair' },
                      { string_term: { single_quoted: var } },
                      { var_ref: var }
                    ]
                  }
                }
              ]
            }
          }
        end
        @closure = Node.from_obj({
                                   fun_call: {
                                     name: '_as',
                                     fun_args: [
                                       variable_capture,
                                       { var_ref: "_fun#{@refid}" }
                                     ]
                                   }
                                 }, tables: tables)
        @closure.line = @line

        get_context = [
          {
            assignment: {
              var: '_wsh_context_map',
              rvalue: {
                fun_call: {
                  name: '_as',
                  fun_args: [
                    { var_ref: '_wsh_context' },
                    { var_ref: 'map' }
                  ]
                }
              }
            }
          }
        ] + tables.locals.map do |var|
          {
            assignment: {
              var: var,
              rvalue: {
                fun_call: {
                  name: 'at',
                  fun_args: [
                    { var_ref: '_wsh_context_map' },
                    { string_term: { single_quoted: var } }
                  ]
                }
              }
            }
          }
        end
        @body = get_context + [slice[:body]].flatten

        # We need to declare the type for _as to work, since we're casting a map as our
        # special type. Since the prototype of call() in the core module is any, and that
        # function is written to unconditonally strip the type instead of using `_as` (for now)
        # we don't need to worry about the fact that _as restricts casting to or from storage_types.
        saved_context = tables.context
        saved_locals = tables.locals
        tables.clear_locals!
        tables.context = nil
        # Back at the top-level temporarily, for function definition and type declaration
        tables.adds << Type.new({ name: "_fun#{@refid}", store_type: 'map' }, tables: tables)
        tables.adds << FunStatement.new({ signature: @signature, body: @body }, tables: tables)
        # Restore the function context
        tables.context = saved_context
        tables.locals = saved_locals
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def errors
        @closure.errors
      end

      def to_s
        # Unchecked cast to fun--will be uncast in call()
        [
          @closure.to_s,
          '_wsh_result="fun+${_wsh_result}"'
        ].join("\n  ")
      end
    end
    # rubocop:enable Metrics/ClassLength

    # meta <field> <data>
    class Meta < Node
      attr_reader :doc, :author, :source, :version

      def initialize(slice, tables:)
        super
        @line = slice[:meta_field].line_and_column[0] if slice[:meta_field].respond_to?(:line_and_column)
        @field = slice[:meta_field].to_s
        case @field
        when 'doc'
          @doc = StringValue.new(slice[:meta_data], tables: tables)
        when 'author'
          @author = StringValue.new(slice[:meta_data], tables: tables)
        when 'version'
          @version = StringValue.new(slice[:meta_data], tables: tables)
        when 'source'
          @source = StringValue.new(slice[:meta_data], tables: tables)
        else
          raise Wrapsher::CompilationError, "Unknown meta field: #{@field} at #{@filename}:#{@line}"
        end
      end

      def to_s
        []
      end
    end

    # module <module>
    class Module < Node
      def initialize(slice, tables:)
        super
        @name = slice.to_s
        if tables.globals.key?(@name)
          raise \
            Wrapsher::CompilationError,
            "Module global name #{@name} conflicts with existing global variable at #{@filename}:#{line}"
        end

        tables.in_module = @name
        tables.globals[@name] = true
      end

      def to_s
        [
          "# module #{@name}",
          "_wsh_set_global #{@name} 'module/#{@name}:#{@filename}'"
        ].join("\n")
      end
    end

    # key: value
    class Pair < Node
      def initialize(slice, tables:)
        super
        @line = slice[:key].line_and_column[0] if slice[:key].respond_to?(:line_and_column)
        @inner = Node.from_obj(inner_ast(slice), tables: tables)
        @inner.line = @line
      end

      def inner_ast(slice)
        {
          fun_call: {
            name: 'from_kv',
            fun_args: [
              { var_ref: 'pair' },
              slice[:key],
              slice[:value]
            ]
          }
        }
      end

      def to_s
        @inner.to_s
      end
    end

    # return <value>
    class Return < Node
      def initialize(slice, tables:)
        super
        @line = slice[:keyword_return].line_and_column[0] if slice[:keyword_return].respond_to?(:line_and_column)
        @depth = 1 + (tables.state[:in_loop] || 0)
        @return_value = Node.from_obj(slice[:return_value], tables: tables)
      end

      def errors
        @return_value.errors
      end

      def to_s
        [
          '  ' + @return_value.to_s,
          "break #{@depth} # return"
        ].join("\n  ")
      end
    end

    # shell <string>
    class ShellCode < Node
      def initialize(slice, tables:)
        super
        @shellcode = StringValue.new(slice, tables: tables)
      end

      def to_s
        @shellcode.to_s
      end
    end

    # string contents
    class StringValue < Node
      attr_reader :value

      def initialize(slice, tables:)
        super
        @string_type = slice.keys.first
        case @string_type
        when :single_quoted
          s = slice[@string_type].to_s
          @value = s.gsub(/\\(.)/) { |m| m[1] }
        else
          @value = slice[@string_type].to_s
        end
      end

      def to_s
        @value
      end
    end

    # '...' | '''...'''
    class StringTerm < Node
      attr_reader :value

      def initialize(slice, tables:)
        super
        @value = StringValue.new(slice, tables: tables)
      end

      def sh_value
        @value.to_s
      end

      def to_s
        [
          "read -r -d '' _wshi <<'EOSTRING'
_wsh_bof#{sh_value}
_wsh_eof
EOSTRING
",
          "_wshi=\"${_wshi%$'\\n'_wsh_eof}\"",
          '_wshi="${_wshi#_wsh_bof}"',
          '_wsh_result="string:${_wshi}"'
        ].join("\n  ")
      end
    end

    # type <type> <store_type>
    class Type < Node
      def initialize(slice, tables:)
        super
        @name = slice[:name].to_s
        @store_type = slice[:store_type].to_s if slice[:store_type]
        if @name !~ %r{^[a-z_][a-z0-9_/]*$} || @name.include?('__')
          raise \
            Wrapsher::CompilationError,
            "Invalid type name '#{@name}' at #{@filename}:#{@line} - " \
            'must start with a letter or underscore, and contain only letters, numbers, underscores, and slashes'
        end

        if tables.globals.key?(@name)
          raise Wrapsher::CompilationError, "redefinition of global variable #{@name} at #{@filename}:#{@line}"
        end

        tables.globals[@name] = true
      end

      def errors
        ["Type #{@name} has nonexistent store type #{@store_type}"] unless tables.globals[@store_type]
      end

      def to_s
        code = []
        code << line
        code << "# type #{@name}"
        code << "_wsh_set_global #{@name} 'type/#{@name}:#{@store_type}'"
        code.join("\n")
      end
    end

    # try { ... } catch <errorvar> { ... }
    class TryBlock < Node
      def initialize(slice, tables:)
        super
        @line = slice[:keyword_try].line_and_column[0] if slice[:keyword_try].respond_to?(:line_and_column)
        @try_body_ast = [slice[:try_body]].flatten
        if slice[:catch][:keyword_catch].respond_to?(:line_and_column)
          @catch_line = slice[:catch][:keyword_catch].line_and_column[0]
        end
        @catch_body_ast = [
          {
            assignment: {
              var: slice[:catch][:var],
              rvalue: {
                shellcode: {
                  triple_quoted: [
                    '  _wsh_result="${_wsh_error}"',
                    "  _wsh_error=''"
                  ].join("\n")
                }
              }
            }
          }
        ] + [slice[:catch][:catch_body]].flatten
        @try_body = Body.new(@try_body_ast, tables: tables)
        @catch_body = Body.new(@catch_body_ast, tables: tables)
      end

      def errors
        [
          @try_body.errors,
          @catch_body.errors
        ]
      end

      def to_s
        code = []
        code << 'while :; do # try'
        code << '  :'
        code << @try_body.to_s
        code << '  break'
        code << 'done'
        code << 'case "${_wsh_error}" in ?*) # catch block'
        code << @catch_body.to_s
        code << ';;'
        code << 'esac # end catch block'
      end
    end

    # use external <command>
    class UseExternal < Node
      def initialize(slice, tables:)
        super
        @external_command = slice.to_s
        tables.external[@external_command] = true
        @line = slice.line_and_column[0]
      end

      def to_s
        []
      end
    end

    # use feature <feature>
    # pragmas
    class UseFeature < Node
      FEATURES = [
        'external'
      ].freeze

      def initialize(slice, tables:)
        super
        @feature_name = slice.to_s
        @line = slice.line_and_column[0] if slice.respond_to?(:line_and_column)
        if tables.in_module
          raise \
            Wrapsher::CompilationError,
            "Can't use features in modules (module #{tables.in_module}) at #{@filename}:#{@line}"
        end
        tables.feature[@feature_name] = true
        @line = slice.line_and_column[0]
      end

      def to_s
        []
      end
    end

    # use global <var> <initial_value>
    class UseGlobal < Node
      def initialize(slice, tables:)
        super
        @line = slice[:name].line_and_column[0] if slice[:name].respond_to?(:line_and_column)
        @global_name = slice[:name].to_s
        @initial_value = Node.from_obj(slice[:value], tables: tables)
        if tables.globals.key?(@global_name)
          raise \
            Wrapsher::CompilationError,
            "Global name #{@global_name} conflicts with existing global name at #{@filename}:#{line}"
        end
        tables.globals[@global_name] = true
      end

      def to_s
        [
          "# use global #{@global_name}",
          @initial_value.to_s,
          "_wsh_set_global '#{@global_name}' \"${_wsh_result}\""
        ].join("\n")
      end
    end

    # use module <module>
    class UseModule < Node
      attr_accessor :included

      def initialize(slice, tables:)
        super
        @module_name = slice.to_s
        @line = slice.line_and_column[0]
        @included_nodes = [include].compact.flatten
      end

      # rubocop:disable Metrics/AbcSize
      def include
        return if tables.included[@module_name]

        wsh_include_path = tables.options[:wsh_include_path] || Wrapsher::Include.path

        wsh_include_path.flat_map do |loc|
          module_filename = "#{loc}/#{@module_name}.wsh"
          if File.exist?(module_filename)
            tables.included[@module_name] = true
            tables.modules += [@module_name]
            saved_filename = tables.filename # TODO: yuck
            tables.filename = module_filename
            module_ast = Wrapsher::Parser.new.parse(module_filename)
            module_transformed = Wrapsher::Transformer.new.transform(module_ast)
            compiled_nodes = [module_transformed].flatten.map do |obj|
              Node.from_obj(obj, tables: tables)
            end
            tables.filename = saved_filename
            tables.in_module = nil
            return compiled_nodes
          end
        end
        raise \
          Wrapsher::CompilationError,
          "Module #{@module_name} not found in include paths: #{wsh_include_path.join(':')}"
      end
      # rubocop:enable Metrics/AbcSize

      def to_s
        [
          "# use module #{@module_name} from #{@filename}:#{@line}",
          @included_nodes.map(&:to_s).join("\n")
        ].compact.map(&:to_s).join("\n")
      end
    end

    # <var>
    class VarRef < Node
      def initialize(slice, tables:)
        super
        @name = slice.to_s
        @defined_locals = tables.locals.dup
      end

      def errors
        return ["variable '#{@name}' does not exist (not global, local or builtin) at #{@filename}:#{@line}"] unless ok

        []
      end

      def ok
        BUILTIN_LOCALS.include?(@name) || tables.globals.key?(@name) || @defined_locals.include?(@name)
      end

      def to_s
        [
          tables.globals[@name] ? "_wsh_result=\"${_wshg_#{@name}}\"" : "_wsh_get_local '#{@name}' _wsh_result"
        ].join("\n  ")
      end
    end

    class Version < Node
    end

    # while <condition> { ... }
    class While < Node
      def initialize(slice, tables:)
        super
        @line = slice[:keyword_while].line_and_column[0] if slice.respond_to? :line_and_column
        @condition = Node.from_obj(slice[:condition], tables: tables)
        tables.state[:in_loop] ||= 0
        tables.state[:in_loop] += 1
        @loop_body = Body.new(slice[:loop_body], tables: tables)
        tables.state[:in_loop] -= 1
      end

      def errors
        [
          @condition.errors,
          @loop_body.errors
        ]
      end

      def to_s
        code = []
        code << 'while :; do # while'
        code << @condition.to_s
        code << "_wsh_assert \"${_wsh_result}\" 'bool' 'while condition' || break"
        code << "case \"${_wsh_result}\" in 'bool:true') : ;; *) break ;; esac"
        code << @loop_body.to_s
        code << 'done # while'
        # Propagate break because it might have been from a throw/error propagation break
        code << 'case "${_wsh_error}" in ?*) break ;; esac'
      end
    end

    def initialize(slice, tables:)
      @filename = tables.filename
      @tables = tables
      @slice = slice
      @line = slice.line_and_column[0] if slice.respond_to? :line_and_column
    end

    def errors
      []
    end

    def to_s
      raise NotImplementedError, "Subclasses(#{self.class}) must implement a to_s method: #{inspect}"
    end

    attr_accessor :line
    attr_reader :filename, :tables

    NODES = {
      assignment: Assignment,
      bool_term: BoolTerm,
      break: Break,
      comment: Comment,
      conditional: Conditional,
      continue: Continue,
      lambda: Lambda,
      empty_map_term: EmptyMapTerm,
      fun_call: FunCall,
      fun_statement: FunStatement,
      int_term: IntTerm,
      list_term: ListTerm,
      module: Module,
      meta: Meta,
      pair: Pair,
      return: Return,
      shellcode: ShellCode,
      string_term: StringTerm,
      struct: Struct,
      try_block: TryBlock,
      type: Type,
      use_external: UseExternal,
      use_feature: UseFeature,
      use_global: UseGlobal,
      use_module: UseModule,
      var_ref: VarRef,
      version: Version,
      while: While
    }.freeze

    BUILTIN_LOCALS = %w[_reflist].freeze

    class << self
      def from_obj(obj, tables:)
        PP.pp(obj, $stderr) unless obj.respond_to?(:keys)
        type = obj.keys.first
        raise NotImplementedError, "Unknown node type: #{type}" unless NODES.key?(type)

        NODES[type].new(obj[type], tables: tables)
      end
    end
  end
end
