# frozen_string_literal: true

def test_fun(body)
  body = [body] unless body.is_a?(Array)
  [{
    fun_statement: {
      signature: {
        type: 'bool',
        name: 'test',
        arg_definitions: nil,
      },
      body: body
    }
  }]
end

RSpec.describe 'parser/transform' do
  it "parses an expression with linebreaks" do
    source = <<~'EOF'
    bool test() {
      x = [
        0,
        1,
        2
      ]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: [
                  { int_term: '0' },
                  { int_term: '1' },
                  { int_term: '2' }
                ]
              }
            }
          }
        ]))
  end

  it "parses a lol" do
    source = <<~'EOF'
    bool test() {
      x = [
        0,
        [0, 1],
        [0, 1, 2]
      ]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: [
                  { int_term: '0' },
                  { list_term: [{ int_term: '0' }, { int_term: '1' }] },
                  { list_term: [{ int_term: '0' }, { int_term: '1' }, { int_term: '2' }] }
                ]
              }
            }
          }
        ]))
  end

  it "parses a lom" do
    source = <<~'EOF'
    bool test() {
      x = [
        ['one': 1, 'two': 2],
        [:],
        ['THREE': 3]
      ]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: [
                  {
                    list_term: [
                      { pair: { key: string_term('one'), value: { int_term: '1' } } },
                      { pair: { key: string_term('two'), value: { int_term: '2' } } }
                    ]
                  },
                  { empty_map_term: '[:]' },
                  {
                    list_term: {
                      pair: { key: string_term('THREE'), value: { int_term: '3' } }
                    }
                  }
                ]
              }
            }
          }
        ]))
  end

  it "parses a mol" do
    source = <<~'EOF'
    bool test() {
      x = [
        'one': [0, 1],
        'two': [0, 1, 2]
      ]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: [
                  {
                    pair: {
                      key: string_term('one'),
                      value: {
                        list_term: [
                          { int_term: '0' },
                          { int_term: '1' }
                        ]
                      }
                    }
                  },
                  {
                    pair: {
                      key: string_term('two'),
                      value: {
                        list_term: [
                          { int_term: '0' },
                          { int_term: '1' },
                          { int_term: '2' }
                        ]
                      }
                    }
                  }
                ]
              }
            }
          }
        ]))
  end

  it "parses a dispatch table", skip: 'TODO: fix lambda parse in map' do
    source = <<~'EOF'
    bool test() {
      x = [
        'add5': int fun (int i) { i + 5 },
        'sub3': int fun (int i) { i - 3 }
      ]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            assignment: {
              var: 'x',
              rvalue: {
                list_term: [
                  {
                    pair: {
                      key: string_term('add5'),
                      value: {
                        lambda: {
                          signature: {
                            type: 'int',
                            arg_definitions: {
                              type: 'int',
                              name: 'i'
                            }
                          },
                          body: {
                            additive_op: {
                              left: { var_ref: 'i' },
                              operator: '+',
                              right: { int_term: '5' }
                            }
                          }
                        }
                      }
                    }
                  },
                  {
                    pair: {
                      key: string_term('sub3'),
                      value: {
                        lambda: {
                          signature: {
                            type: 'int',
                            arg_definitions: {
                              type: 'int',
                              name: 'i'
                            }
                          },
                          body: {
                            additive_op: {
                              left: { var_ref: 'i' },
                              operator: '-',
                              right: { int_term: '3' }
                            }
                          }
                        }
                      }
                    }
                  }
                ]
              }
            }
          }
        ]))
  end

  it "parses a chain" do
    source = <<~'EOF'
    bool test() {
      i.to_string().quote()
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            postfix_chain: {
              receiver: { var_ref: 'i' },
              calls: [
                { fun_call: { name: 'to_string', fun_args: nil } },
                { fun_call: { name: 'quote', fun_args: nil } }
              ]
            }
          }
        ]))
    program = Wrapsher::Transformer.new.transform(ast)
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'quote',
              fun_args: [
                {
                  fun_call: {
                    name: 'to_string',
                    fun_args: [
                      { var_ref: 'i' }
                    ]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses an empty string" do
    source = <<~'EOF'
    bool test() {
      ''
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          { string_term: { single_quoted: [] } }
        ]))
    program = Wrapsher::Transformer.new.transform(ast)
    expect(program).to eq(
      test_fun([
          { string_term: { single_quoted: '' } }
          ]))
  end

  it "parses a throw expression" do
    source = <<~'EOF'
    bool test() {
      throw 'No such program'
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([{ throw: string_term('No such program') }]))
    program = Wrapsher::Transformer.new.transform(ast)
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'throw',
              fun_args: [
                string_term('No such program')
              ]
            }
          }
        ]))
  end

  it "parses a try/catch block" do
    source = <<~'EOF'
    bool test() {
      try {
        x = 1
      } catch e {
        throw e
      }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            try_block: {
              keyword_try: 'try',
              try_body: [
                { assignment: { var: 'x', rvalue: { int_term: '1' } } }
              ],
              catch: {
                var: 'e',
                keyword_catch: 'catch',
                catch_body: [
                  {
                    throw: { var_ref: 'e' }
                  }
                ]
              }
            }
          }
        ]))
  end

  it "parses line comments at the top level" do
    source = <<~'EOF'
    # Intro to function
    # Second comment
    bool test() {
      false
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      [
        { comment: ' Intro to function' },
        { comment: ' Second comment' }
      ] + test_fun([{ bool_term: 'false' }])
      )
  end

  it "parses line comments in a function", skip: 'TODO: fix line comments in blocks' do
    source = <<~'EOF'
    bool test() {
      # Intro to function
      false
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          { comment: ' Intro to function' },
          { bool_term: 'false'}
        ]))
  end

  it "parses block ends with trailing whitespace" do
    source = <<~'EOF'
    bool test() {
      false
    } 
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          { bool_term: 'false' }
        ]))
  end

  it "parses negative ints" do
    source = <<~'EOF'
    bool test() {
      -10
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          { int_term: '-10' }
        ]))
  end

  it "parses strings" do
    source = <<~'EOF'
    bool test() {
      '\''
      '\\back'
      '\'\''
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          string_term("\\'"),
          string_term("\\\\back"),
          string_term("\\'\\'")
        ]))
  end

  it "parses an empty map" do
    source = <<~EOF
    bool test() {
      [:]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'new',
              fun_args: [{ var_ref: 'map' }]
            }
          }
        ]))
  end

  it "parses an empty map in a function call" do
    source = <<~'EOF'
    bool test() {
      y._x(p, [:])
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: '_x',
              fun_args: [
                { var_ref: 'y' },
                { var_ref: 'p' },
                {
                  fun_call: {
                    name: 'new',
                    fun_args: [{ var_ref: 'map' }]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses a pair in an expression" do
    source = <<~'EOF'
    bool test() {
      p = 'key1': 'value1'
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
         {
            assignment: {
              var: 'p',
              rvalue: {
                fun_call: {
                  name: 'from_kv',
                  fun_args: [
                    { var_ref: 'pair' },
                    string_term('key1'),
                    string_term('value1')
                  ]
                }
              }
            }
          }
        ]))
  end

  it "parses a boolean expression" do
    source = <<~'EOF'
    bool test() {
      x and y or not z
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            boolean_op: [
              { left: { var_ref: 'x' } },
              { operator: 'and', right: { var_ref: 'y' } },
              { operator: 'or', right: {
                  boolean_not: {
                    subject: { var_ref: 'z' }
                  }
                }
              }
            ]
          }
        ]))
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'or',
              fun_args: [
                {
                  fun_call: {
                    name: 'and',
                    fun_args: [
                      { var_ref: 'x' },
                      { var_ref: 'y' }
                    ]
                  }
                },
                {
                  fun_call: {
                    name: 'not',
                    fun_args: [
                      { var_ref: 'z' }
                    ]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses a pair in a complex expression" do
    source = <<~'EOF'
    bool test() {
      p == 'key1': 'value1'
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            comparison: {
              left: { var_ref: 'p' },
              operator: '==',
              right: {
                pair: {
                  key: string_term('key1'),
                  value: string_term('value1')
                }
              }
            }
          }
        ]))
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'eq',
              fun_args: [
                { var_ref: 'p' },
                {
                  fun_call: {
                    name: 'from_kv',
                    fun_args: [
                      { var_ref: 'pair' },
                      string_term('key1'),
                      string_term('value1')
                    ]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses a pair in an expression with chains" do
    source = <<~'EOF'
    bool test() {
      m.head() == 'key1': 'value1'
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'eq',
              fun_args: [
                {
                  fun_call: {
                    name: 'head',
                    fun_args: [
                      { var_ref: 'm' }
                    ]
                  }
                },
                {
                  fun_call: {
                    name: 'from_kv',
                    fun_args: [
                      { var_ref: 'pair' },
                      string_term('key1'),
                      string_term('value1')
                    ]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses a pair" do
    source = <<~EOF
    bool test() {
      'key1': 'value1'
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'from_kv',
              fun_args: [
                { var_ref: 'pair' },
                string_term('key1'),
                string_term('value1')
              ]
            }
          }
        ]))
  end

  it "parses a map" do
    source = <<~EOF
    bool test() {
      ['key1': 'value1', 'key2': 'value2']
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            list_term: [
              {
                pair: {
                  key: string_term('key1'),
                  value: string_term('value1')
                }
              },
              {
                pair: {
                  key: string_term('key2'),
                  value: string_term('value2')
                }
              }
            ]
          }
        ]))
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'from_pairlist',
              fun_args: [
                { var_ref: 'map' },
                {
                  fun_call: {
                    name: 'push',
                    fun_args: [
                      {
                        fun_call: {
                          name: 'push',
                          fun_args: [
                            {
                              fun_call: {
                                name: 'new',
                                fun_args: [{ var_ref: 'list' }]
                              }
                            },
                            {
                              fun_call: {
                                name: 'from_kv',
                                fun_args: [
                                  { var_ref: 'pair' },
                                  string_term('key1'),
                                  string_term('value1')
                                ]
                              }
                            }
                          ]
                        }
                      },
                      {
                        fun_call: {
                          name: 'from_kv',
                          fun_args: [
                            { var_ref: 'pair' },
                            string_term('key2'),
                            string_term('value2')
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          }
          ]))
    end

  it "evaluates != as a chain" do
    source = <<~EOF
    bool test() {
      a != b
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'not',
              fun_args: {
                fun_call: {
                  name: 'eq',
                  fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                }
              }
            }
          }
        ]))
  end

  it "evaluates >= as a chain" do
    source = <<~EOF
    bool test() {
      a >= b
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'not',
              fun_args: {
                fun_call: {
                  name: 'lt',
                  fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                }
              }
            }
          }
        ]))
  end

  it "parses an anonymous function" do
    source = <<~EOF
    bool test() {
      bool fun (int a, int b) {
        a == b
      }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            lambda: {
              signature: {
                type: 'bool',
                arg_definitions: [
                  { type: 'int', name: 'a' },
                  { type: 'int', name: 'b' }
                ]
              },
              body: [
                {
                  fun_call: {
                    name: 'eq',
                    fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses an anonymous function in a single line" do
    source = <<~EOF
    bool test() {
      bool fun (int a, int b) { a + b; a == b }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            lambda: {
              signature: {
                type: 'bool',
                arg_definitions: [
                  { type: 'int', name: 'a' },
                  { type: 'int', name: 'b' }
                ]
              },
              body: [
                {
                  additive_op: [
                    { left: { var_ref: 'a' } },
                    { operator: '+', right: { var_ref: 'b' } }
                  ]
                },
                {
                  comparison: {
                    left: { var_ref: 'a' },
                    operator: '==',
                    right: { var_ref: 'b' }
                  }
                }
              ]
            }
          }
        ]))
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            lambda: {
              signature: {
                type: 'bool',
                arg_definitions: [
                  { type: 'int', name: 'a' },
                  { type: 'int', name: 'b' }
                ]
              },
              body: [{
                  fun_call: {
                    name: 'plus',
                    fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                  }
                }, {
                  fun_call: {
                    name: 'eq',
                    fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                  }
                }
              ]
            }
          }
        ]))
  end

  it "parses an anonymous function in an assignment" do
    source = <<~EOF
    bool test() {
      f = bool fun (int a, int b) { a == b }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            assignment: {
              var: 'f',
              rvalue: {
                lambda: {
                  signature: {
                    type: 'bool',
                    arg_definitions: [
                      { type: 'int', name: 'a' },
                      { type: 'int', name: 'b' }
                    ]
                  },
                  body: {
                    fun_call: {
                      name: 'eq',
                      fun_args: [{ var_ref: 'a' }, { var_ref: 'b' }]
                    }
                  }
                }
              }
            }
          }
        ]))
  end

  it "parses an anonymous function in an expression" do
    source = <<~EOF
    bool test() {
      l.filter(bool fun (string s) { s.length() > 0 }, other)
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'filter',
              fun_args: [
                { var_ref: 'l' },
                {
                  lambda: {
                    signature: {
                      type: 'bool',
                      arg_definitions: { type: 'string', name: 's' }
                    },
                    body: {
                      fun_call: {
                        name: 'gt',
                        fun_args: [
                          {
                            fun_call: {
                              name: 'length',
                              fun_args: [{ var_ref: 's' }]
                            }
                          },
                          { int_term: '0' }
                        ]
                      }
                    }
                  }
                },
                { var_ref: 'other' }
              ]
            }
          }
        ]))
  end

  it "parses a subscript" do
    source = <<~EOF
    bool test() {
      x[0]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            subscript: [
              { receiver: { var_ref: 'x' } },
              { index: { int_term: '0' } }
            ]
          }
        ]))
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'at',
              fun_args: [{var_ref: 'x'}, {int_term: '0'}]
            }
          }
        ]))
  end

  it "parses a multidimensional subscript" do
    source = <<~EOF
    bool test() {
      x[0]['foo']
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
      test_fun([
          {
            subscript: [
              { receiver: { var_ref: 'x' } },
              { index: { int_term: '0' } },
              { index: string_term('foo') }
            ]
          }
        ]))
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'at',
              fun_args: [
                {
                  fun_call: {
                    name: 'at',
                    fun_args: [{var_ref: 'x'}, {int_term: '0'}]
                  }
                },
                string_term('foo')
              ]
            }
          }
        ]))
  end

  it "parses an empty list" do
    source = <<~EOF
    bool test(){
      [ ]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
     test_fun([
          {
            fun_call: {
              name: 'new',
              fun_args: [{var_ref: 'list'}]
            }
          }
        ]))
  end

  it "parses an additive expression" do
    source = <<~'EOF'
    bool test() {
      x.to_string() + ' ' + ' '
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    # plus(plus(to_string(x), string_term(' ')), to_string(y))
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'plus',
              fun_args: [
                {
                  fun_call: {
                    name: 'plus',
                    fun_args: [
                      {
                        fun_call: {
                          name: 'to_string',
                          fun_args: [
                            {var_ref: 'x'}
                          ]
                        }
                      },
                      string_term(' ')
                    ]
                  }
                },
                string_term(' ')
              ]
            }
          }
        ]))
  end

  it "parses a list literal" do
    source = <<~EOF
    bool test() {
      [1, 2, 3]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            fun_call: {
              name: 'push',
              fun_args: [
                {
                  fun_call: {
                    name: 'push',
                    fun_args: [
                      {
                        fun_call: {
                          name: 'push',
                          fun_args: [
                            {
                              fun_call: {
                                name: 'new',
                                fun_args: [
                                  { var_ref: 'list' }
                                ]
                              }
                            },
                            { int_term: '1' }
                          ]
                        }
                      },
                      { int_term: '2' }
                    ]
                  }
                },
                { int_term: '3' }
              ]
            }
          }
        ]))
  end

  it "parses a list with expressions" do
    source = <<~EOF
    bool test() {
      x = [0, a.to_string(), not b, 3 - 4]
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
      test_fun([
          {
            assignment: {
              var: 'x',
              rvalue:
              {:fun_call=>
                {:fun_args=>
                  [{:fun_call=>
                      {:fun_args=>
                        [{:fun_call=>
                            {:fun_args=>
                              [{:fun_call=>
                                  {:fun_args=>
                                    [{:fun_call=>
                                        {:fun_args=>[{:var_ref=>"list"}],
                                          :name=>"new"}},
                                      {:int_term=>"0"}],
                                    :name=>"push"}},
                                {:fun_call=>
                                  {:fun_args=>[{:var_ref=>"a"}],
                                    :name=>"to_string"}}],
                              :name=>"push"}},
                          {:fun_call=>{:fun_args=>[{:var_ref=>"b"}], :name=>"not"}}],
                        :name=>"push"}},
                    {:fun_call=>
                      {:fun_args=>[{:int_term=>"3"}, {:int_term=>"4"}],
                        :name=>"minus"}}],
                  :name=>"push"}}
            }
          }]))
  end

  it "parses a return call" do
    source = <<~'EOF'
    bool test() {
      if x > 0 {
        return false
      }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
        test_fun([
            {
              conditional: {
                keyword_if: 'if',
                condition: {
                  fun_call: {
                    name: 'gt',
                    fun_args: [
                      { var_ref: 'x' },
                      { int_term: '0' }
                    ]
                  }
                },
              then: [
                  {
                    return: {
                      keyword_return: 'return',
                      return_value: {
                        bool_term: 'false'
                      }
                    }
                  }
                ]
              }
            }
          ]))
    end

  it "parses a break call" do
    source = <<~'EOF'
    bool test() {
      while x > 0 {
        break
      }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
        test_fun([
            {
              while: {
                keyword_while: 'while',
                condition: {
                  fun_call: {
                    name: 'gt',
                    fun_args: [
                      { var_ref: 'x' },
                      { int_term: '0' }
                    ]
                  }
                },
                loop_body: [
                  { break: 'break' }
                ]
              }
            }
          ]))
  end

  it "parses a continue call" do
    source = <<~'EOF'
    bool test() {
      while x > 0 {
        continue
      }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
        test_fun([
            {
              while: {
                keyword_while: 'while',
                condition: {
                  fun_call: {
                    name: 'gt',
                    fun_args: [
                      { var_ref: 'x' },
                      { int_term: '0' }
                    ]
                  }
                },
                loop_body: [
                  { continue: 'continue' }
                ]
              }
            }
          ]))
  end

  it "parses a while loop" do
    source = <<~'EOF'
    bool test() {
      while x > 0 {
        true
      }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq(
        test_fun([
            {
              while: {
                keyword_while: 'while',
                condition: {
                  fun_call: {
                    name: 'gt',
                    fun_args: [
                      { var_ref: 'x' },
                      { int_term: '0' }
                    ]
                  }
                },
                loop_body: [{ bool_term: 'true' }]
              }
            }
          ]))
  end

  it "parses a function definition" do
    source = <<~EOF
    int add(int a, int b) {
      a * b
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq([
      {
        fun_statement: {
          signature: {
            type: 'int',
            name: 'add',
            arg_definitions: [
              {
                type: 'int',
                name: 'a'
              },
              {
                type: 'int',
                name: 'b'
              }
            ]
          },
          body: [
            {
               multiplicative_op: [
                 { left: { var_ref: 'a' } },
                 { operator: '*', right: { var_ref: 'b' } }
               ]
            }
          ]
        }
      }
    ])
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
    expect(program).to eq([
      {
        fun_statement: {
          signature: {
            type: 'int',
            name: 'add',
            arg_definitions: [
              {
                type: 'int',
                name: 'a'
              },
              {
                type: 'int',
                name: 'b'
              }
            ]
          },
          body: [
            {
              fun_call: {
                name: 'times',
                fun_args: [
                  { var_ref: 'a' },
                  { var_ref: 'b' }
                ]
              }
            }
          ]
        }
      }
    ])
  end

  it "parses an if-else-if chain" do
    source = <<~'EOF'
    bool test() {
      if x > 100 {
         100
      } else if x > 10 {
         10
      } else {
         1
      }
    }
    EOF
    ast = stringify(Wrapsher::Parser.new.parsetext(source)).flatten
    expect(ast).to eq(
                  test_fun([
                      {
                        conditional: [
                          {
                            keyword_if: 'if',
                            condition: {
                              comparison: {
                                left: { var_ref: 'x' },
                                operator: '>',
                                right: { int_term: '100' }
                              }
                            },
                          then: [
                              { int_term: '100' }
                            ]
                          },
                          {
                            keyword_elseif: 'else if',
                            condition: {
                              comparison: {
                                left: { var_ref: 'x' },
                                operator: '>',
                                right: { int_term: '10' }
                              }
                            },
                          then: [
                              { int_term: '10' }
                            ]
                          },
                          {
                            keyword_else: 'else',
                            else: [
                              { int_term: '1' }
                            ]
                          }
                        ]
                      }
                    ]))
    program = stringify(Wrapsher::Transformer.new.transform(ast)).flatten
        expect(program).to eq(
                  test_fun([
                      {
                        conditional: {
                          keyword_if: 'if',
                          condition: {
                            fun_call: {
                              name: 'gt',
                              fun_args: [{ var_ref: 'x' }, { int_term: '100' }]
                            }
                          },
                        then: [{ int_term: '100' }],
                          keyword_else: 'else if',
                        else: {
                            conditional: {
                              keyword_if: 'else if',
                              keyword_elseif: 'else if',
                              condition: {
                                fun_call: {
                                  name: 'gt',
                                  fun_args: [{ var_ref: 'x' }, { int_term: '10' }]
                                }
                              },
                            then: [{ int_term: '10' }],
                              keyword_else: 'else',
                            else: [
                                { int_term: '1' }
                              ]
                            }
                          }
                        }
                      }
                    ]))
  end

  it "parses some wrapsher" do
    source = <<~EOF
    module ex
    meta author 'dev@mermaidpurse.org'
    use version 0
    type vector list
    EOF
    parser = Wrapsher::Parser.new()
    ast = stringify(parser.parsetext(source)).flatten
    expect(ast).to eq([
          { module: 'ex' },
          { meta: { meta_field: 'author', meta_data: { single_quoted: 'dev@mermaidpurse.org' } } },
          { use_version: '0' },
          { type: {name: 'vector', store_type: 'list' } }
        ])
  end

end
