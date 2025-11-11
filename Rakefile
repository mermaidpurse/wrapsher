# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'json'

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

task default: %i[spec rubocop]

namespace :profile do
  desc <<~DESC
    Convert JSON event stream FILE into Chrome traceEvents file.
      Usage:
        rake "profile:trace[trace.jsons]"
        rake "profile:trace[trace.jsons,trace.json]"
  DESC
  task :trace, [:stream_file, :output_file] do |_, args|
    args.with_defaults(
      stream_file: nil,
      output_file: nil
    )

    stream_file = args[:stream_file] or abort 'stream_file is required (first arg)'
    abort "stream_file not found: #{stream_file}" unless File.file?(stream_file)

    output_file = args[:output_file]
    unless output_file
      dir = File.dirname(stream_file)
      ext = File.extname(stream_file)
      base = File.basename(stream_file, ext)
      ext = ext == '.jsons' ? '.json' : '.trace.json'
      output_file = File.join(dir, "#{base}#{ext}")
    end

    events = []
    File.foreach(stream_file) do |line|
      line = line.strip
      next if line.empty?

      events << JSON.parse(line)
    end

    trace = {
      traceEvents: events,
      displayTimeUnit: 's'
    }

    File.write(output_file, JSON.pretty_generate(trace))
    puts "Wrote #{output_file} (#{events.size} events)"
  end
end
