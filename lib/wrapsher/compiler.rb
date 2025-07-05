require 'logger'
require 'wrapsher'

module Wrapsher
  class Compiler
    def initialize(logger: nil, level: nil)
      @logger = logger || Logger.new($stderr)
      @logger.level = level || :DEBUG
    end

    def compiletext(text, type: :program, tables: Wrapsher::ProgramTables.new)
      ast = Wrapsher::Parser.new.parsetext(text)
      Wrapsher::Generator.new(type: type).generate(ast, tables: tables)
    end

    def compile(filename, type: :program, tables: Wrapsher::ProgramTables.new)
      text = File.read(filename)
      compiletext(text, type: type, tables: tables)
    end
  end
end
