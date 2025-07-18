require 'fileutils'
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
        opts.on('-D', '--debug', 'Print debugging output on stderr') { @options[:level] = :DEBUG }
      end
    end

    def run()
      case @cmd
      when 'help'
        help @argv
      when 'run'
        do_run @argv
      when 'test'
        do_test @argv
      when 'compile'
        do_compile @argv
      when 'transform'
        do_transform @argv
      when 'parse'
        do_parse @argv
      else
        help
      end
    end

    def help(args=nil)
      puts <<EOF
Usage:
  wrapsher COMMAND [options...]

  Run wrapsher COMMAND --help for help:
    wrapsher compile
    wrapsher run
    wrapsher test
    wrapsher transform
    wrapsher parse
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
          source = File.expand_path(source)
          output = source.delete_suffix('.wsh')
          compiled = compiler.compile(
            source,
            tables: Wrapsher::ProgramTables.new(filename: source, logger: @logger),
            type: :program
          )
          File.open(output, 'w', 0o755) { |fh| fh.write(compiled) }
          system(output)
          Process.exit($?.exitstatus)
        end
      end
    end

    def do_test(args)
      args = @file_optparser.parse(*args)
      compiler = Wrapsher::Compiler.new(logger: @logger, level: @options[:level])

      if ! @options[:expr].empty?
        raise ArgumentError, 'Cannot test expressions directly, please provide a file'
      else
        # TODO: Discover test files
        args.each do |source|
          output = source.delete_suffix('.wsh')
          # TODO: change to :test ?
          compiled = compiler.compile(
            source,
            type: :program,
            tables: Wrapsher::ProgramTables.new(filename: source, logger: @logger)
          )
          File.open(output, 'w', 0o755) { |fh| fh.write(compiled) }
          system(output)
          FileUtils.rm_f(output) if $?.exitstatus == 0
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
          compiled = compiler.compile(
            source,
            type: :program,
            tables: Wrapsher::ProgramTables.new(filename: source, logger: @logger)
          )
          File.open(output, 'w', 0o755) { |fh| fh.write(compiled) }
        end
      end
    end

    def do_transform(args)
      args = @file_optparser.parse(*args)
      parser = Wrapsher::Parser.new(logger: @logger, level: @options[:level])
      if ! @options[:expr].empty?
        parsed = parser.parsetext(@options[:expr].join("\n") + "\n")
        transformed = Wrapsher::Transformer.new(logger: @logger, level: @options[:level]).transform(parsed)
        pp transformed
        puts JSON.pretty_generate(transformed)
      else
        args.each do |source|
          ppoutput = source.delete_suffix('.wsh') + '.pp'
          output = source.delete_suffix('.wsh') + '.json'
          parsed = parser.parse(source)
          transformed = Wrapsher::Transformer.new(logger: @logger, level: @options[:level]).transform(parsed)
          File.open(ppoutput, 'w') { |fh| PP.pp(transformed, fh) }
          File.open(output, 'w') { |fh| fh.write(JSON.pretty_generate(transformed)) }
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
  end
end
