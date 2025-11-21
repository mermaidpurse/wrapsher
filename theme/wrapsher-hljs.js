hljs.registerLanguage("wrapsher", (hljs) => ({
  name: "Wrapsher",
  keywords: {
    keyword: "if else use module meta type struct fun return while break continue shell throw try catch",
    built_in: "any int bool string reflist ref list map pair error builtin",
    literal: "true false",
  },
  contains: [
    // single-quoted strings: '...'
    hljs.APOS_STRING_MODE,
    // numbers
    hljs.C_NUMBER_MODE,
    // triple single-quoted strings: '''...'''
    {
      scope: "string",
      begin: /'''/,
      end: /'''/,
      contains: [{ begin: /\\./ }],
    },
    // identifiers immediately followed by '(' (calls/defs)
    {
      className: "function",
      begin: /(?!\d)[A-Za-z_\/][A-Za-z0-9_\/]*\s*(?=\()/,
      contains: [{ className: "title", begin: /(?!\d)[A-Za-z_\/][A-Za-z0-9_\/]*/ }],
    },
    // # comments (with TODO/FIXME/NOTE recognized by many themes)
    hljs.COMMENT("#", "$"),
  ],
}));

hljs.initHighlightingOnLoad();
