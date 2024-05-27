# frozen_string_literal: true

RSpec.describe Wrapsher::Parser do

  it "parses some wrapsher" do
    source = <<-EOF
module ex
use version 0
EOF
    parser = Wrapsher::Parser.new()
    program = stringify(parser.parsetext(source))
    expect(program).to eq([{ module: 'ex' }, { version: '0' }])
  end
end
