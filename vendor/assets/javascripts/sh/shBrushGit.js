// Git brush for SyntaxHighlighter

(function() {
  // CommonJS
  typeof(require) != 'undefined' ? SyntaxHighlighter = require('shCore').SyntaxHighlighter : null;

  function Brush() {
    this.regexList = [
      { regex: /^commit (\w+)$/gm, css: 'keyword' }
    ]
  }

  Brush.prototype = new SyntaxHighlighter.Highlighter();
  Brush.aliases = ['git', 'commit'];

  SyntaxHighlighter.brushes.Git = Brush;

  // CommonJS
  typeof(exports) != 'undefined' ? exports.Brush = Brush : null;
})();
