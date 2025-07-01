require 'json'
require 'logger'
require 'optparse'
require 'wrapsher'
require 'pry'

module Wrapsher

  class CLI

    def self.run(argv)
      me = self.new(argv)
      me.run
    end

    def initialize(argv)
      @cmd = argv.shift
      @argv = argv
      @logger = Logger.new $stderr
      @options = {
        expr:  [],
        level: :INFO
      }
      @file_optparser = OptionParser.new do |opts|
        opts.on('-eCODE', '--expr CODE', 'Expression/Wrapsher code to process') { |expr| @options[:expr] << expr }
        opts.on('-D', '--debug', 'Print debugging output on stderr') { |debug| @options[:level] = :DEBUG }
      end
    end

    def run()
      case @cmd
      when 'help'
        help @argv
      when 'run'
        do_run @argv
      when 'compile'
        do_compile @argv
      when 'parse'
        do_parse @argv
      when 'grammar'
        do_grammar
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

    def do_run(args)
      args = @file_optparser.parse(*args)
      compiler = Wrapsher::Compiler.new(logger: @logger, level: @options[:level])

      if ! @options[:expr].empty?
        compiled = compiler.compiletext(@options[:expr].join("\n") + "\n")
        IO.popen('/bin/sh', 'w') { |sh| sh.write(compiled) }
      else
        args.each do |source|
          output = source.delete_suffix('.wsh')
          compiled = compiler.compile(source)
          File.open(output, 'w', 0o755) { |fh| fh.write(compiled) }
          system(output)
          Process.exit($?.exitstatus)
        end
      end
    end

    def do_compile(args)
      args      = @file_optparser.parse(*args)
      compiler  = Wrapsher::Compiler.new(logger: @logger, level: @options[:level])

      if ! @options[:expr].empty?
        compiled = compiler.compiletext(@options[:expr].join("\n") + "\n")
        puts compiled
      else
        args.each do |source|
          output = source.delete_suffix('.wsh')
          compiled = compiler.compile(source)
          File.open(output, 'w', 0o755) { |fh| fh.write(compiled) }
        end
      end
    end

    def do_parse(args)
      args   = @file_optparser.parse(*args)
      parser = Wrapsher::Parser.new(logger: @logger, level: @options[:level])
      if ! @options[:expr].empty?
        parsed = parser.parsetext(@options[:expr].join("\n") + "\n")
        pp parsed
        puts JSON.pretty_generate(parsed)
      else
        args.each do |source|
          ppoutput = source.delete_suffix('.wsh') + '.pp'
          output = source.delete_suffix('.wsh') + '.json'
          parsed = parser.parse(source)
          File.open(ppoutput, 'w') { |fh| PP.pp(parsed, fh) }
          File.open(output, 'w') { |fh| fh.write(JSON.pretty_generate(parsed)) }
        end
      end
    end

    def do_grammar()
      parser = Wrapsher::Parser.new(logger: @logger, level: @options[:level])
      puts parser.grammar
    end

  end

end
