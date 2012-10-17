/**
 * SyntaxHighlighter
 * http://alexgorbatchev.com/
 *
 * SyntaxHighlighter is donationware. If you are using it, please donate.
 * http://alexgorbatchev.com/wiki/SyntaxHighlighter:Donate
 *
 * @version
 * 2.0.320 (May 03 2009)
 * 
 * @copyright
 * Copyright (C) 2004-2009 Alex Gorbatchev.
 *
 * @license
 * This file is part of SyntaxHighlighter.
 * 
 * SyntaxHighlighter is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * SyntaxHighlighter is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with SyntaxHighlighter.  If not, see <http://www.gnu.org/copyleft/lesser.html>.
 */
SyntaxHighlighter.brushes.AS3 = function() {
	
	// Created by Gabriel Mariani @ http://blog.coursevector.com
	
	var primaryKeywords =	'class dynamic extends implements import interface new case do while else if for ' +
							'in switch throw intrinsic private public static get set function var try catch finally ' +
							'while with default break continue delete return final each label internal native ' +
							'override protected const namespace package include use AS3';
	
	var secondaryKeywords =	'super this null Infinity -Infinity NaN undefined true false is as instanceof typeof';
	
	var additionalKeywords = 	'void Null ArgumentError arguments Array Boolean Class Date DefinitionError Error EvalError ' +
								'Function int Math Namespace Number Object QName RangeError ReferenceError RegExp SecurityError ' +
								'String SyntaxError TypeError uint URIError	VerifyError XML XMLList Accessibility ' +
								'AccessibilityProperties ActionScriptVersion AVM1Movie Bitmap BitmapData BitmapDataChannel ' +
								'BlendMode CapsStyle DisplayObject DisplayObjectContainer FrameLabel GradientType Graphics ' +
								'IBitmapDrawable InteractiveObject InterpolationMethod JointStyle LineScaleMode Loader LoaderInfo ' +
								'MorphShape MovieClip PixelSnapping Scene Shape SimpleButton SpreadMethod Sprite Stage StageAlign ' +
								'StageDisplayState StageQuality StageScaleMode SWFVersion EOFError IllegalOperationError ' +
								'InvalidSWFError IOError MemoryError ScriptTimeoutError StackOverflowError ActivityEvent ' +
								'AsyncErrorEvent ContextMenuEvent DataEvent ErrorEvent Event EventDispatcher EventPhase FocusEvent ' +
								'FullScreenEvent HTTPStatusEvent IEventDispatcher IMEEvent IOErrorEvent KeyboardEvent MouseEvent ' +
								'NetStatusEvent ProgressEvent SecurityErrorEvent StatusEvent SyncEvent TextEvent TimerEvent ' +
								'ExternalInterface BevelFilter BitmapFilter BitmapFilterQuality BitmapFilterType BlurFilter ' +
								'ColorMatrixFilter ConvolutionFilter DisplacementMapFilter DisplacementMapFilterMode ' +
								'DropShadowFilter GlowFilter GradientBevelFilter GradientGlowFilter ColorTransform Matrix Point ' +
								'Rectangle Transform Camera ID3Info Microphone Sound SoundChannel SoundLoaderContext SoundMixer ' +
								'SoundTransform Video FileFilter FileReference FileReferenceList IDynamicPropertyOutput ' +
								'IDynamicPropertyWriter LocalConnection	NetConnection NetStream ObjectEncoding Responder ' +
								'SharedObject SharedObjectFlushStatus Socket URLLoader URLLoaderDataFormat URLRequest ' +
								'URLRequestHeader URLRequestMethod URLStream URLVariables XMLSocket	PrintJob PrintJobOptions ' +
								'PrintJobOrientation ApplicationDomain Capabilities IME IMEConversionMode LoaderContext	Security ' +
								'SecurityDomain SecurityPanel System AntiAliasType CSMSettings Font FontStyle FontType GridFitType ' +
								'StaticText StyleSheet TextColorType TextDisplayMode TextField TextFieldAutoSize TextFieldType TextFormat ' +
								'TextFormatAlign TextLineMetrics TextRenderer TextSnapshot ContextMenu ContextMenuBuiltInItems ' +
								'ContextMenuItem Keyboard KeyLocation Mouse ByteArray Dictionary Endian IDataInput IDataOutput ' +
								'IExternalizable Proxy Timer XMLDocument XMLNode XMLNodeType' +
								
								/* Global Methods */
								'decodeURI decodeURIComponent encodeURI encodeURIComponent escape isFinite isNaN isXMLName ' +
								'parseFloat parseInt trace unescape ' +
								
								/* Flash 10 */
								'NetStreamPlayOptions ShaderParameter NetStreamInfo DigitCase FontWeight Kerning FontDescription ' +
								'LigatureLevel RenderingMode TextElement FontPosture TextLineValidity TextLineCreationResult ' +
								'BreakOpportunity ContentElement TabStop TabAlignment JustificationStyle FontMetrics TextLineMirrorRegion ' +
								'TextLine CFFHinting ElementFormat GraphicElement DigitWidth TextJustifier TextBlock GroupElement ' +
								'TypographicCase EastAsianJustifier LineJustification SpaceJustifier FontLookup TextRotation TextBaseline ' +
								'TriangleCulling ShaderData GraphicsEndFill ColorCorrectionSupport ShaderInput GraphicsGradientFill ' +
								'GraphicsPathWinding GraphicsStroke ShaderParameterType IGraphicsStroke ShaderJob GraphicsBitmapFill ' +
								'IGraphicsData Shader GraphicsPath IGraphicsFill GraphicsShaderFill ShaderPrecision IDrawCommand ' +
								'GraphicsTrianglePath ColorCorrection GraphicsPathCommand IGraphicsPath GraphicsSolidFill ShaderFilter ' +
								'NetStreamPlayTransitions SoundCodec ContextMenuClipboardItems MouseCursor ClipboardTransferMode Clipboard ' +
								'ClipboardFormats Vector';
	
	var documentationKeywords = '@author @copy @default @deprecated @eventType @example @exampleText @exception @haxe @inheritDoc @internal @link ' +
								'@mtasc @mxmlc @param @private @return @see @serial @serialData @serialField @since @throws @usage @version';
	
	this.regexList = [
		{ regex: SyntaxHighlighter.regexLib.singleLineCComments,			css: 'comments' },				// one line comments
		{ regex: SyntaxHighlighter.regexLib.multiLineCComments,				css: 'comments' },				// multiline comments
		{ regex: SyntaxHighlighter.regexLib.doubleQuotedString,				css: 'string' },				// double quoted strings
		{ regex: SyntaxHighlighter.regexLib.singleQuotedString,				css: 'string' },				// single quoted strings
		{ regex: /^\\s*#.*/gm,												css: 'preprocessor' },			// preprocessor tags like #region and #endregion
		{ regex: /\/.*\/[gism]+/g,											css: 'constants' },				// regex
		{ regex: new RegExp(this.getKeywords(documentationKeywords), 'gm'),	css: 'color1' },				// documentation keywords
		{ regex: new RegExp(this.getKeywords(primaryKeywords), 'gm'),		css: 'keyword' },				// primary keywords
		{ regex: new RegExp(this.getKeywords(secondaryKeywords), 'gm'),		css: 'color2' },				// secondary keywords
		{ regex: /\b([\d]+(\.[\d]+)?|0x[a-f0-9]+)\b/gi,						css: 'value' },					// numbers
		{ regex: new RegExp(this.getKeywords(additionalKeywords), 'gm'),	css: 'color3' }					// additional keywords
		];
	
	this.forHtmlScript(SyntaxHighlighter.regexLib.scriptScriptTags);
};

SyntaxHighlighter.brushes.AS3.prototype	= new SyntaxHighlighter.Highlighter();
SyntaxHighlighter.brushes.AS3.aliases	= ['actionscript3', 'as3'];
