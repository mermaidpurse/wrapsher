# frozen_string_literal: true

require 'logger'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'compile/errors' do
  subject(:compile) do
    logger = Logger.new $stderr
    compiler = Wrapsher::Compiler.new(logger: logger, level: :info)
    compiler.compiletext(
      program,
      type: :program,
      tables: Wrapsher::ProgramTables.new(filename: '-', logger: logger)
    )
  end

  describe 'break outside of loop' do
    let(:program) do
      <<~PROGRAM
        bool test() {
          break
        }
      PROGRAM
    end

    it 'raises an error' do
      expect { compile }.to raise_error(Wrapsher::CompilationError)
    end
  end

  describe 'invalid type name' do
    let(:program) do
      <<~PROGRAM
        type foo__bar string
      PROGRAM
    end

    it 'raises an error' do
      expect { compile }.to raise_error(Wrapsher::CompilationError)
    end
  end

  describe 'uninitialized variable' do
    let(:program) do
      <<~PROGRAM
        bool test() {
          x
        }
      PROGRAM
    end

    it 'raises an error' do
      expect { compile }.to raise_error(Wrapsher::CompilationError)
    end
  end

  describe 'redefine function' do
    let(:program) do
      <<~PROGRAM
        bool test() {
          false
        }

        bool test() {
          true
        }
      PROGRAM
    end

    it 'raises an error' do
      expect { compile }.to raise_error(Wrapsher::CompilationError)
    end
  end

  describe 'bad store type' do
    let(:program) do
      <<~PROGRAM
        type foo bar
      PROGRAM
    end

    it 'raises an error' do
      expect { compile }.to raise_error(Wrapsher::CompilationError)
    end
  end

  describe 'global/module conflict' do
    let(:program) do
      <<~PROGRAM
        module foo
        use global foo false
      PROGRAM
    end

    it 'raises an error' do
      expect { compile }.to raise_error(Wrapsher::CompilationError)
    end
  end

  describe 'module/global conflict' do
    let(:program) do
      <<~PROGRAM
        use global foo 0
        module foo
      PROGRAM
    end

    it 'raises an error' do
      expect { compile }.to raise_error(Wrapsher::CompilationError)
    end
  end
end
# rubocop:enable Metrics/BlockLength
