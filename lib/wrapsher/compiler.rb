require 'logger'
require 'wrapsher'

module Wrapsher
  class Compiler

    def initialize(logger: nil, level: nil)
      @logger = logger || Logger.new($stderr)
      @logger.level = level || :DEBUG
    end

    def compiletext(text, filename: '-e')
      ast = Wrapsher::Parser.new.parsetext(text)
      Wrapsher::Generator.new.generate(ast, filename: filename)
    end

    def compile(filename)
      text = File.read(filename)
      compiletext(text, filename: filename)
    end

  end
end
