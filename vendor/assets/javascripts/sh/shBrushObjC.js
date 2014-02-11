;(function() {

	typeof(require) != 'undefined' ? SyntaxHighlighter = require('shCore').SyntaxHighlighter : null;
    
    function Brush()	{

        var datatypes = 'char bool BOOL double float int long short id void';
        
        var keywords = 'IBAction IBOutlet SEL YES NO readwrite readonly nonatomic NULL'
                     + ' super self copy if else for in enum while typedef switch case return'
                     + ' const static retain TRUE FALSE ON OFF';
                
        this.regexList = [
                { regex: new RegExp(this.getKeywords(datatypes), 'gm'), css: 'color2' },        // primitive data types
                { regex: new RegExp(this.getKeywords(keywords), 'gm'),  css: 'color2' },        // keywords
                { regex: new RegExp('@\\w+\\b', 'g'),                   css: 'color2' },        // @-keywords
                { regex: new RegExp('[: ]nil', 'g'),                    css: 'color2' },        // nil-workaround
                { regex: new RegExp(' \\w+(?=[:\\]])', 'g'),            css: 'variable' },      // messages
                { regex: SyntaxHighlighter.regexLib.singleLineCComments,css: 'comments' },      // comments
                { regex: SyntaxHighlighter.regexLib.multiLineCComments, css: 'comments' },      // comments
                { regex: new RegExp('@"[^"]*"', 'gm'),                  css: 'string' },        // strings
                { regex: new RegExp('\\d', 'gm'),                       css: 'string' },        // numeric values
                { regex: new RegExp('^ *#.*', 'gm'),                    css: 'preprocessor' },  // preprocessor
                { regex: new RegExp('\\w+(?= \\*)', 'g'),               css: 'keyword' },       // object types - variable declaration
                { regex: new RegExp('\\b[A-Z]\\w+\\b(?=[ ,;])', 'gm'),  css: 'keyword' },       // object types - protocol
                { regex: new RegExp('\\.\\w+', 'g'),                    css: 'constants' }      // accessors
        ];
    };
    Brush.prototype	= new SyntaxHighlighter.Highlighter();
	Brush.aliases	= ['oc', 'obj-c'];

	SyntaxHighlighter.brushes.ObjC = Brush;

	typeof(exports) != 'undefined' ? exports.Brush = Brush : null;

})();
