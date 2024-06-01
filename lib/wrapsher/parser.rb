require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

module Wrapsher
  class Parser < Parslet::Parser

    def initialize(logger: nil, level: nil)
      @logger = logger || Logger.new($stderr)
      @logger.level = level || :DEBUG
    end

    def parsetext(text)
      begin
        Wrapsher::Syntax.new.parse(text)
      rescue Parslet::ParseFailed => e
        @logger.error(e.parse_failure_cause.ascii_tree)
        raise
      end
    end

    def parsefile(filename)
      text = File.read(filename)
      parsetext(text)
    end

  end
end
