require 'wrapsher'

module Wrapsher
  # Global compiler information for a program
  class ProgramTables
    attr_accessor :filename, :functions, :globals, :feature, :external, :included, :compiler_refid, :adds,
                  :options, :context, :locals, :state, :modules, :in_module

    def initialize(
      filename: '-',
      functions: {},
      globals: {},
      external: {},
      feature: {},
      included: {},
      compiler_refid: 1000,
      adds: [],
      logger: Logger.new($stderr),
      options: {},
      modules: [],
      in_module: nil
    )
      @filename = filename
      @functions = functions
      @globals = globals
      @external = external
      @feature = feature
      @included = included
      @compiler_refid = compiler_refid
      @adds = adds
      @context = nil
      @locals = []
      @state = {}
      @logger = logger
      @options = options
      @modules = modules
      @in_module = in_module
      @logger.debug("ProgramTables initialized with logger level: #{@logger.level}, filename: #{@filename}, refid: #{@compiler_refid}")
    end

    def log(message)
      @logger.debug(message)
    end

    def push_local(name)
      @locals ||= []
      @locals << name
    end

    def clear_locals!
      @locals = []
    end

    def refid
      @compiler_refid += 1
      @compiler_refid
    end

    def to_nodes
      nodes = []
      nodes << Node::UseGlobal.new(
        {
          name: '_filename',
          value: {
            string_term: {
              single_quoted: @filename
            }
          }
        },
        tables: self
      )
      nodes << Node::UseGlobal.new(
        {
          name: '_globals',
          value: {
            bool_term: 'false'
          }
        },
        tables: self
      )
      nodes << Node::UseGlobal.new(
        {
          name: '_externals',
          value: {
            bool_term: 'false'
          }
        },
        tables: self
      )
      nodes += feature_assignments
      nodes << Node::UseGlobal.new(
        {
          name: '_functions',
          value: {
            bool_term: 'false'
          }
        },
        tables: self
      )
      nodes << Node::FunStatement.new(
        {
          signature: {
            name: '_init',
            type: 'bool',
            arg_definitions: []
          },
          body: [
            {
              assignment: {
                var: '_functions',
                rvalue: functions_rvalue
              }
            },
            {
              assignment: {
                var: '_globals',
                rvalue: globals_rvalue
              }
            },
            {
              assignment: {
                var: '_externals',
                rvalue: externals_rvalue
              }
            },
            module_init_calls,
            { bool_term: 'true' }
          ].flatten
        },
        tables: self
      )
      nodes += adds
      nodes
    end

    def feature_assignments
      Node::UseFeature::FEATURES.map do |feature_name|
        Node::UseGlobal.new(
          {
            name: "_feature_#{feature_name}",
            value: {
              bool_term: feature[feature_name] ? 'true' : 'false'
            }
          },
          tables: self
        )
      end
    end

    def externals_rvalue
      external.keys.reduce(
        {
          fun_call: {
            name: 'new',
            fun_args: [{ var_ref: 'list' }]
          }
        }
      ) do |acc, external_name|
        {
          fun_call: {
            name: 'push',
            fun_args: [acc, { string_term: { single_quoted: external_name } }]
          }
        }
      end
    end

    def globals_rvalue
      globals.keys.reduce(
        {
          fun_call: {
            name: 'new',
            fun_args: [{ var_ref: 'list' }]
          }
        }
      ) do |acc, global_name|
        {
          fun_call: {
            name: 'push',
            fun_args: [acc, { string_term: { single_quoted: global_name } }]
          }
        }
      end
    end

    def functions_rvalue
      functions.keys.reduce(
        {
          fun_call: {
            name: 'new',
            fun_args: [{ var_ref: 'list' }]
          }
        }
      ) do |acc, fn_name|
        {
          fun_call: {
            name: 'push',
            fun_args: [acc, { string_term: { single_quoted: fn_name } }]
          }
        }
      end
    end

    def module_init_calls
      modules.map do |module_name|
        next unless functions['init']["module/#{module_name}"]

        {
          fun_call: {
            name: 'init',
            fun_args: [{ var_ref: module_name }]
          }
        }
      end.compact
    end

    def to_s
      lines = []
      lines << "filename: #{filename}"
      lines << "globals: #{globals.keys.join(' ')}"
      lines << "external: #{external.keys.join(' ')}"
      lines << 'included:'
      included.each do |modname, source|
        lines << "  #{modname} => #{source}"
      end
      lines << 'functions:'
      functions.each do |function_name, fntab|
        lines << "  #{function_name}:"
        fntab.each do |dispatch_type, signature|
          lines << "    #{dispatch_type}: #{signature.summary}"
        end
      end
      lines.join("\n")
    end
  end
end
