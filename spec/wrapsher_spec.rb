# frozen_string_literal: true

RSpec.describe Wrapsher do
  it "has a version number" do
    expect(Wrapsher::VERSION).not_to be nil
  end

  it "parses some wrapsher" do
    source = <<EOF
module ex
use version 0
EOF
    parser = Wrapsher::Parser.new(trace: :DEBUG)
    program = parser.parsetext(source)
    expect(progarm).to_eq({ version: 0, module: 'ex' })
  end
end
