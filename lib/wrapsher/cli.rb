require 'logger'
require 'wrapsher'

module Wrapsher

  class CLI

    def self.run(argv)
      me = self.new(argv)
      me.run
    end

    def initialize(argv)
      @cmd = argv.shift
      @argv = argv
    end

    def run()
      case @cmd
      when 'help'
        help @argv
      when 'parse'
        parse @argv
      when 'grammar'
        grammar
      else
        help
      end
    end

    def help(args=nil)
      puts <<EOF
Usage:
  wrapsher COMMAND [options...]

  Run wrapsher COMMAND --help for help:
    wrapsher parse
    wrapsher grammar
EOF
    end

    def parse(args)
      @logger = Logger.new $stderr
      parser = Wrapsher::Parser.new(logger: @logger, level: :DEBUG)
      args.each do |text|
        pp parser.parsetext(text)
      end
    end

    def grammar()
      @logger = Logger.new $stderr
      parser = Wrapsher::Parser.new(logger: @logger, level: :DEBUG)
      puts parser.grammar
    end

  end

end
