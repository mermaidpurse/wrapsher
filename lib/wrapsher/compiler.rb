require 'logger'
require 'wrapsher'

module Wrapsher
  class Compiler

    def initialize(logger: nil, level: nil)
      @logger = logger || Logger.new($stderr)
      @logger.level = level || :DEBUG
    end

    def compiletext(text, type: :program, filename: '-e')
      ast = Wrapsher::Parser.new.parsetext(text)
      Wrapsher::Generator.new(type: type).generate(ast, filename: filename)
    end

    def compile(filename, type: :program)
      text = File.read(filename)
      compiletext(text, filename: filename, type: type)
    end

  end
end
