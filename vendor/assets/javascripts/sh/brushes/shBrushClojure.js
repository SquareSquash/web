SyntaxHighlighter.brushes.Clojure = function()
{
        // Contributed by Travis Whitton

        var funcs = ':arglists :doc :file :line :macro :name :ns :private :tag :test new alias alter ' +
                    'and apply assert class cond conj count def defmacro defn defstruct deref do '     +
                    'doall dorun doseq dosync eval filter finally find first fn gen-class gensym if '  +
                    'import inc keys let list loop map ns or print println quote rand recur reduce '   +
                    'ref repeat require rest send seq set sort str struct sync take test throw '       +
                    'trampoline try type use var vec when while';

        this.regexList = [
                { regex: new RegExp(';[^\]]+$', 'gm'),                           css: 'comments' },
		{ regex: SyntaxHighlighter.regexLib.multiLineDoubleQuotedString, css: 'string' },
                { regex: /\[|\]/g,                                               css: 'keyword' },
		{ regex: /'[a-z][A-Za-z0-9_]*/g,                                 css: 'color1' }, // symbols
		{ regex: /:[a-z][A-Za-z0-9_]*/g,                                 css: 'color2' }, // keywords
		{ regex: new RegExp(this.getKeywords(funcs), 'gmi'),             css: 'functions' }
            ];
 
	this.forHtmlScript(SyntaxHighlighter.regexLib.aspScriptTags);
}

SyntaxHighlighter.brushes.Clojure.prototype     = new SyntaxHighlighter.Highlighter(); 
SyntaxHighlighter.brushes.Clojure.aliases       = ['clojure', 'Clojure', 'clj'];
