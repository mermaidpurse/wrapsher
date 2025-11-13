# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2025 Mermaidpurse

require 'logger'
require 'wrapsher'

module Wrapsher
  # Compile Wrapsher
  class Compiler
    def initialize(logger: nil, level: nil)
      @logger = logger || Logger.new($stderr)
      @logger.level = level || :DEBUG
    end

    def compiletext(text, type: :program, tables: Wrapsher::ProgramTables.new)
      ast = Wrapsher::Parser.new(logger: @logger, level: @logger.level).parsetext(text)
      transformed_ast = Wrapsher::Transformer.new(logger: @logger, level: @logger.level).transform(ast)
      Wrapsher::Generator.new(type: type).generate(transformed_ast, tables: tables)
    end

    def docstext(text, type: :program, tables: Wrapsher::ProgramTables.new)
      ast = Wrapsher::Parser.new(logger: @logger, level: @logger.level).parsetext(text)
      transformed_ast = Wrapsher::Transformer.new(logger: @logger, level: @logger.level).transform(ast)
      Wrapsher::Generator.new(type: type).docs(transformed_ast, tables: tables)
    end

    def docs(filename, type: :program, tables: Wrapsher::ProgramTables.new)
      text = File.read(filename)
      docstext(text, type: type, tables: tables)
    end

    def compile(filename, type: :program, tables: Wrapsher::ProgramTables.new)
      text = File.read(filename)
      compiletext(text, type: type, tables: tables)
    end
  end
end
