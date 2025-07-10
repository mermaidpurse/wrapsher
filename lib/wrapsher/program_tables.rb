require 'wrapsher'

module Wrapsher
  class ProgramTables
    attr_accessor :filename, :functions, :globals, :external, :included, :compiler_refid, :adds,
                  :context, :locals

    def initialize(
        filename: '-',
        functions: {},
        globals: {},
        external: {},
        included: {},
        compiler_refid: 1000,
        adds: [])
      @filename = filename
      @functions = functions
      @globals = globals
      @external = external
      @included = included
      @compiler_refid = compiler_refid
      @adds = adds
      @context = nil
    end

    def push_local(name)
      @locals ||= []
      @locals << name
    end

    def clear_locals
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
                rvalue: functions.keys.uniq.reduce({
                    fun_call: {
                      name: 'new',
                      fun_args: [ {var_ref: 'list'} ]
                    }
                  }) do |acc, fn_name|
                  {
                    fun_call: {
                      name: 'push',
                      fun_args: [acc, { string_term: { single_quoted: fn_name } }]
                    }
                  }
                end
              }
            },
            { bool_term: 'true' }
          ],
        },
        tables: self
      )
      nodes += self.adds
      nodes
    end

    def to_s
      lines = []
      lines << "filename: #{filename}"
      lines << "globals: #{globals.keys.join(" ")}"
      lines << "external: #{external.keys.join(" ")}"
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
