require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

module Wrapsher
  class Transformer

    def initialize(logger: nil, level: nil)
      @logger = logger || Logger.new($stderr)
      @logger.level = level || :DEBUG
    end

    def transform(ast)
      Wrapsher::Transform.new.apply(ast)
    end
  end
end
