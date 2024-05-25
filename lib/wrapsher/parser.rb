require 'ebnf'
require 'ebnf/terminals'
require 'ebnf/peg/parser'
require 'json'
require 'logger'
require 'sxp'
require 'wrapsher'

module Wrapsher
  class Parser
    include EBNF::PEG::Parser

    attr_reader :ast

    def initialize(**options)
      @options = options
      @program = {}
      @logger = @options[:logger] || Logger.new($stderr)
      # Load Wrapsher grammar
      ebnf = File.expand_path("../wsh/wrapsher.ebnf", __FILE__)
      @rules = EBNF.parse(File.open(ebnf)).make_peg.ast
      @logger.debug(grammar)
      if @options.has_key?(:trace)
        @options[:logger] = @logger
        @options[:logger].level = @options[:trace]
        @options[:logger].formatter = lambda {|severity, datetime, progname, msg| "#{severity} #{msg}\n"}
      end
    end

    def grammar
      @rules.to_sxp
    end

    def parsefile(file)
      # TODO: maintain file location for parsing
      parsetext(File.read(file))
    end

    def dbg(msg)
      @log ||= []
      @log << msg
    end

    def parsetext(input)
      @logger.debug("options: #{@options}")
      @logger.debug(input.inspect)
      parse(input, :PROGRAM, @rules, **@options)
      @logger.debug(@log.inspect)
      @program
    end

    production(:PROGRAM, clear_packrat: true) do |value|
      # I guess we don't really do anything
    end

    start_production(:MODULE_STATEMENT) do |data|
      @state = :module
    end
    production(:MODULE_STATEMENT, clear_packrat: true) do |value|
      @state = nil
    end

    start_production(:USE_STATEMENT) do |data|
      @state = :use_version
    end
    production(:USE_STATEMENT, clear_packrat: true) do |value|
      @state = nil
    end

    production(:WORD, clear_packrat: true) do |value|
      case @state
      when :module
        @program[:module] = value
      when :use_version
        @program[:use] ||= {}
        @program[:use][:version] = value
      end
    end

  end
end
