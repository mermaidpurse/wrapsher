# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2025 Mermaidpurse

require 'wrapsher'

module Wrapsher
  # Global compiler information for a program
  # rubocop:disable Metrics/ClassLength
  class ProgramTables
    attr_accessor :filename, :functions, :globals, :feature, :external, :included, :compiler_refid, :adds,
                  :options, :context, :locals, :state, :modules, :in_module

    # rubocop:disable Metrics/ParameterLists
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
      @logger.debug(
        "ProgramTables initialized with logger level: #{@logger.level}, " \
        "filename: #{@filename}, refid: #{@compiler_refid}"
      )
    end
    # rubocop:enable Metrics/ParameterLists

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
      nodes += use_globals(%w[_globals _externals _functions])
      nodes += feature_assignments
      nodes << program_init_call
      nodes += adds
      nodes
    end

    # nullary _init - global program init
    # rubocop:disable Metrics/MethodLength
    def program_init_call
      Node::FunStatement.new(
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
    end
    # rubocop:enable Metrics/MethodLength

    def use_globals(globals)
      globals.map do |global|
        Node::UseGlobal.new(
          {
            name: global,
            value: {
              bool_term: 'false'
            }
          },
          tables: self
        )
      end
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
  # rubocop:enable Metrics/ClassLength
end
