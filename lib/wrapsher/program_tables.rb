require 'wrapsher'

module Wrapsher
  class ProgramTables
    attr_accessor :filename, :functions, :globals, :external, :included

    def initialize(filename: '-', functions: {}, globals: {}, external: {}, included: {})
      @filename = filename
      @functions = functions
      @globals = globals
      @external = external
      @included = included
    end

    def to_nodes
      filename = Node::UseGlobal.new(
        {
          name: '_filename',
          value: {
            string_term: {
              single_quoted: @filename
            }
          }
        },
        tables: self
      )
      [filename]
    end

    def to_s
      lines = []
      lines << "filename: #{filename}"
      lines << "globals: #{globals.keys.join(" ")}"
      lines << "external: #{external.keys.join(" ")}"
      lines << 'included:'
      included.each do |modname, source|
        lines << "  #{modname} => #{source}"
      end
      lines << 'functions:'
      functions.each do |function_name, fntab|
        lines << "  #{function_name}:"
        fntab.each do |dispatch_type, signature|
          lines << "    #{dispatch_type}: #{signature.summary}"
        end
      end
      lines.join("\n")
    end
  end
end
