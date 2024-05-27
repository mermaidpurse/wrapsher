# frozen_string_literal: true

RSpec.describe Wrapsher::Parser do

  it "parses some wrapsher" do
    source = <<-EOF
module ex
meta author 'dev@mermaidpurse.org'
use version 0
type vector
EOF
    parser = Wrapsher::Parser.new()
    program = stringify(parser.parsetext(source))
    expect(program).to eq([
                            { module: 'ex' },
                            { meta_field: 'author', meta_data: { single_quoted: 'dev@mermaidpurse.org' } },
                            { version: '0' },
                            { type: 'vector' }
                          ])
  end
end
