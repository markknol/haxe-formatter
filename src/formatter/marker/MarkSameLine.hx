package formatter.marker;

import formatter.config.SameLineConfig;
import formatter.config.WhitespaceConfig;

class MarkSameLine extends MarkerBase {
	public function run() {
		markDollarSameLine();

		parsedCode.root.filterCallback(function(token:TokenTree, index:Int):FilterResult {
			if ((token.parent != null) && (token.parent.is(At))) {
				return GO_DEEPER;
			}
			switch (token.tok) {
				case Kwd(KwdIf):
					markIf(token);
				case Kwd(KwdElse):
					markElse(token);
				case Kwd(KwdFor):
					markFor(token);
				case Kwd(KwdWhile):
					if ((token.parent != null) && (token.parent.is(Kwd(KwdDo)))) {
						return GO_DEEPER;
					}
					markWhile(token);
				case Kwd(KwdDo):
					markDoWhile(token);
				case Kwd(KwdTry):
					markTry(token);
				case Kwd(KwdCatch):
					markCatch(token);
				case Kwd(KwdCase):
					markCase(token);
				case Kwd(KwdDefault):
					markCase(token);
				case Kwd(KwdFunction):
					markFunction(token);
				case Kwd(KwdMacro):
					markMacro(token);
				case Kwd(KwdReturn):
					markReturn(token);
				default:
			}
			return GO_DEEPER;
		});
	}

	function isExpression(token:Null<TokenTree>):Bool {
		if (token == null) {
			return false;
		}
		var parent:TokenTree = token.parent;
		if (parent.tok == null) {
			return false;
		}
		switch (parent.tok) {
			case Kwd(KwdReturn):
				return true;
			case Arrow:
				return true;
			case Kwd(KwdUntyped):
				return isExpression(parent);
			case Kwd(KwdFor), Kwd(KwdWhile):
				if (parent.parent.is(BkOpen)) {
					return true;
				}
			case Binop(_):
				return true;
			case POpen:
				var pos:Position = parent.getPos();
				if ((pos.min < token.pos.min) && (pos.max > token.pos.max)) {
					return true;
				}
			case Kwd(KwdElse):
				return shouldElseBeSameLine(parent);
			case DblDot:
				return isReturnExpression(parent);
			default:
		}

		return false;
	}

	function isReturnExpression(token:TokenTree):Bool {
		var parent:TokenTree = token;
		while (parent.parent.tok != null) {
			parent = parent.parent;
			switch (parent.tok) {
				case Binop(_):
					return true;
				case Kwd(KwdReturn):
					return true;
				case Arrow:
					return true;
				case Kwd(KwdFunction):
					return false;
				case POpen:
					return true;
				case DblDot:
					return true;
				case BkOpen:
					return false;
				case BrOpen:
					var type:BrOpenType = TokenTreeCheckUtils.getBrOpenType(parent);
					switch (type) {
						case BLOCK:
						case TYPEDEFDECL:
						case OBJECTDECL:
							return true;
						case ANONTYPE:
						case UNKNOWN:
					}
				default:
			}
		}
		return false;
	}

	function shouldIfBeSameLine(token:Null<TokenTree>):Bool {
		if (token == null) {
			return false;
		}
		if (!token.is(Kwd(KwdIf))) {
			return false;
		}
		var body:Null<TokenTree> = getBodyAfterCondition(token);
		if (body == null) {
			return false;
		}
		if (!parsedCode.isOriginalSameLine(token, body)) {
			return false;
		}

		return isExpression(token);
	}

	function shouldElseBeSameLine(token:Null<TokenTree>):Bool {
		if (token == null) {
			return false;
		}
		if (!token.is(Kwd(KwdElse))) {
			return false;
		}

		return shouldIfBeSameLine(token.parent);
	}

	function shouldTryBeSameLine(token:Null<TokenTree>):Bool {
		if (token == null) {
			return false;
		}
		if (!token.is(Kwd(KwdTry))) {
			return false;
		}
		return isExpression(token);
	}

	function shouldCatchBeSameLine(token:Null<TokenTree>):Bool {
		if (token == null) {
			return false;
		}
		if (!token.is(Kwd(KwdCatch))) {
			return false;
		}
		return shouldTryBeSameLine(token.parent);
	}

	function markIf(token:TokenTree) {
		if (shouldIfBeSameLine(token)) {
			switch (config.sameLine.expressionIf) {
				case Same:
					markBodyAfterPOpen(token, Same, config.sameLine.expressionIfWithBlocks);
					return;
				case Keep:
					markBodyAfterPOpen(token, Keep, config.sameLine.expressionIfWithBlocks);
					return;
				case Next:
			}
		}
		markBodyAfterPOpen(token, config.sameLine.ifBody, false);
		var prev:Null<TokenInfo> = getPreviousToken(token);
		if ((prev != null) && (prev.token.is(Kwd(KwdElse)))) {
			applySameLinePolicy(token, config.sameLine.elseIf);
		}
	}

	function markElse(token:TokenTree) {
		if (shouldElseBeSameLine(token)) {
			switch (config.sameLine.expressionIf) {
				case Same:
					markBody(token, Same, config.sameLine.expressionIfWithBlocks);
					var prev:Null<TokenInfo> = getPreviousToken(token);
					if (prev == null) {
						return;
					}
					if (prev.token.is(BrClose)) {
						applySameLinePolicyChained(token, config.sameLine.ifBody, config.sameLine.ifElse);
					}
					return;
				case Keep:
					markBody(token, Keep, config.sameLine.expressionIfWithBlocks);
					if (parsedCode.isOriginalNewlineBefore(token)) {
						lineEndBefore(token);
					}
					var prev:Null<TokenInfo> = getPreviousToken(token);
					if (prev == null) {
						return;
					}
					if (prev.token.is(BrClose)) {
						applySameLinePolicyChained(token, Keep, Keep);
					}
					return;
				case Next:
			}
		}

		markBody(token, config.sameLine.elseBody, false);
		applySameLinePolicyChained(token, config.sameLine.ifBody, config.sameLine.ifElse);
	}

	function markTry(token:TokenTree) {
		if (shouldTryBeSameLine(token) && config.sameLine.expressionTry == Same) {
			markBody(token, Same, false);
			return;
		}
		markBody(token, config.sameLine.tryBody, false);
	}

	function markCatch(token:TokenTree) {
		if (shouldCatchBeSameLine(token) && config.sameLine.expressionTry == Same) {
			markBodyAfterPOpen(token, Same, false);
			applySameLinePolicy(token, config.sameLine.tryCatch);
			return;
		}
		markBodyAfterPOpen(token, config.sameLine.catchBody, false);
		applySameLinePolicyChained(token, config.sameLine.tryBody, config.sameLine.tryCatch);
	}

	function markCase(token:TokenTree) {
		if (token == null) {
			return;
		}
		var dblDot:TokenTree = token.access().firstOf(DblDot).token;
		if (dblDot == null) {
			return;
		}
		if (isReturnExpression(token)) {
			markExpressionCase(token, dblDot);
			return;
		}

		if ((dblDot.children == null) || (dblDot.children.length > 1)) {
			return;
		}
		switch (config.sameLine.caseBody) {
			case Same:
			case Keep:
				if (!parsedCode.isOriginalSameLine(dblDot, dblDot.getFirstChild())) {
					return;
				}
			case Next:
				return;
		}
		var first:Null<TokenTree> = dblDot.getFirstChild();
		var last:Null<TokenTree> = TokenTreeCheckUtils.getLastToken(first);
		if (parsedCode.linesBetweenOriginal(first, last) > 2) {
			return;
		}
		noLineEndAfter(dblDot);
	}

	function markExpressionCase(token:TokenTree, dblDot:TokenTree) {
		if (dblDot.children == null) {
			return;
		}

		switch (config.sameLine.expressionCase) {
			case Same:
			case Keep:
				if (!parsedCode.isOriginalSameLine(dblDot, dblDot.getFirstChild())) {
					return;
				}
			case Next:
				return;
		}
		if (dblDot.children.length == 2) {
			var second:Null<TokenTree> = dblDot.children[1];
			switch (second.tok) {
				case CommentLine(_):
					var prev:Null<TokenInfo> = getPreviousToken(second);
					if (prev != null) {
						if (!parsedCode.isOriginalSameLine(dblDot, prev.token)) {
							return;
						}
					}
				default:
					return;
			}
		}
		if (dblDot.children.length > 2) {
			return;
		}
		noLineEndAfter(dblDot);
	}

	function markFor(token:TokenTree) {
		if (token == null) {
			return;
		}
		var parent:Null<TokenTree> = token.parent;
		if ((parent == null) || (parent.tok == null)) {
			return;
		}
		switch (parent.tok) {
			case BkOpen:
				markArrayComprehension(token, parent);
				return;
			case Kwd(KwdMacro):
				var lastToken:Null<TokenTree> = TokenTreeCheckUtils.getLastToken(token);
				if (lastToken == null) {
					return;
				}
				if (parsedCode.isOriginalSameLine(token, lastToken)) {
					markBodyAfterPOpen(token, Same, false);
					return;
				}
			default:
		}
		markBodyAfterPOpen(token, config.sameLine.forBody, false);
	}

	function markWhile(token:TokenTree) {
		if (token == null) {
			return;
		}
		var parent:Null<TokenTree> = token.parent;
		if ((parent == null) || (parent.tok == null)) {
			return;
		}
		switch (parent.tok) {
			case BkOpen:
				markArrayComprehension(token, parent);
				return;
			default:
		}
		markBodyAfterPOpen(token, config.sameLine.whileBody, false);
	}

	function markArrayComprehension(token:TokenTree, bkOpen:TokenTree) {
		var bkClose:Null<TokenTree> = bkOpen.access().firstOf(BkClose).token;
		switch (config.sameLine.comprehensionFor) {
			case Keep:
				if (parsedCode.isOriginalNewlineBefore(token)) {
					lineEndBefore(token);
				}
				markBodyAfterPOpen(token, config.sameLine.comprehensionFor, false);
				if ((bkClose != null) && (parsedCode.isOriginalNewlineBefore(bkClose))) {
					lineEndBefore(bkClose);
				}
			case Same:
				var origSame:Bool = false;
				if (bkClose != null) {
					origSame = parsedCode.isOriginalSameLine(bkOpen, bkClose);
				}
				if (origSame) {
					whitespace(token, NoneBefore);
					markBodyAfterPOpen(token, config.sameLine.comprehensionFor, false);
					whitespace(bkClose, NoneBefore);
				} else {
					lineEndAfter(bkOpen);
					markBodyAfterPOpen(token, config.sameLine.forBody, false);
				}
			case Next:
				// do nothing
		}
	}

	function getBodyAfterCondition(token:TokenTree):Null<TokenTree> {
		var pClose:Null<TokenTree> = token.access().firstOf(POpen).firstOf(PClose).token;
		if (pClose != null) {
			var next:TokenInfo = getNextToken(pClose);
			if (next != null) {
				switch (next.token.tok) {
					case DblDot:
					default:
						return next.token;
				}
			}
		}
		if (token.children == null) {
			return null;
		}
		for (child in token.children) {
			switch (child.tok) {
				case BrOpen:
					return child;
				case At:
				case Const(CIdent(_)):
					return child.nextSibling;
				case Kwd(KwdTrue), Kwd(KwdFalse), Kwd(KwdNull):
					return child.nextSibling;
				default:
			}
		}
		return null;
	}

	function markBodyAfterPOpen(token:TokenTree, policy:SameLinePolicy, includeBrOpen:Bool) {
		var body:Null<TokenTree> = getBodyAfterCondition(token);
		while (body != null) {
			switch (body.tok) {
				case BrOpen:
					var type:BrOpenType = TokenTreeCheckUtils.getBrOpenType(body);
					switch (type) {
						case BLOCK:
							if (includeBrOpen) {
								markBlockBody(body, policy);
							}
							return;
						case TYPEDEFDECL:
						case OBJECTDECL:
							applySameLinePolicy(body, policy);
						case ANONTYPE:
						case UNKNOWN:
					}
					body = body.nextSibling;
				case Sharp(MarkLineEnds.SHARP_ELSE_IF), Sharp(MarkLineEnds.SHARP_ELSE), Sharp(MarkLineEnds.SHARP_END):
					return;
				case CommentLine(_):
					var prev:Null<TokenInfo> = getPreviousToken(body);
					if (prev != null) {
						if (!parsedCode.isOriginalSameLine(body, prev.token)) {
							applySameLinePolicy(body, policy);
							return;
						}
					}
					body = body.nextSibling;
				default:
					break;
			}
		}
		if (body == null) {
			return;
		}

		applySameLinePolicy(body, policy);
	}

	function markBody(token:TokenTree, policy:SameLinePolicy, includeBrOpen:Bool) {
		var body:Null<TokenTree> = token.access().firstChild().token;
		if (body == null) {
			return;
		}
		if (body.is(BrOpen)) {
			var type:BrOpenType = TokenTreeCheckUtils.getBrOpenType(body);
			switch (type) {
				case BLOCK:
					if (includeBrOpen) {
						markBlockBody(body, policy);
					}
					return;
				case TYPEDEFDECL:
				case OBJECTDECL:
					applySameLinePolicy(body, policy);
				case ANONTYPE:
				case UNKNOWN:
			}
			return;
		}
		applySameLinePolicy(body, policy);
	}

	function markBlockBody(token:TokenTree, policy:SameLinePolicy) {
		if (token == null) {
			return;
		}
		if (!token.is(BrOpen)) {
			return;
		}
		if (token.children == null) {
			return;
		}

		var lastChild:Null<TokenTree> = token.getLastChild();
		if (lastChild.is(Semicolon)) {
			if (token.children.length > 3) {
				return;
			}
		} else {
			if (token.children.length > 2) {
				return;
			}
		}
		noLineEndAfter(token);
		for (child in token.children) {
			switch (child.tok) {
				case BrClose:
					var next:Null<TokenInfo> = getNextToken(child);
					switch (next.token.tok) {
						case Kwd(KwdElse):
							noLineEndAfter(child);
						case Kwd(KwdCatch):
							noLineEndAfter(child);
						case Semicolon:
							whitespace(child, NoneAfter);
						case Comma:
							whitespace(child, NoneAfter);
						default:
					}
					return;
				default:
					var lastToken:TokenTree = TokenTreeCheckUtils.getLastToken(child);
					if (lastToken == null) {
						return;
					}
					noLineEndAfter(lastToken);
			}
		}
	}

	function applySameLinePolicyChained(token:TokenTree, previousBlockPolicy:SameLinePolicy, policy:SameLinePolicy) {
		if (policy == Same) {
			var prev:Null<TokenInfo> = getPreviousToken(token);
			if (prev == null) {
				policy = Next;
			}
			if ((!prev.token.is(BrClose)) && (previousBlockPolicy != Same)) {
				policy = Next;
			}
		}
		applySameLinePolicy(token, policy);
	}

	function applySameLinePolicy(token:TokenTree, policy:SameLinePolicy) {
		switch (policy) {
			case Keep:
				if (parsedCode.isOriginalNewlineBefore(token)) {
					applySameLinePolicy(token, Next);
				} else {
					applySameLinePolicy(token, Same);
				}
			case Same:
				wrapBefore(token, true);
				var prev:Null<TokenInfo> = getPreviousToken(token);
				if (prev == null) {
					noLineEndBefore(token);
				} else {
					switch (prev.token.tok) {
						case POpen, Dot:
							whitespace(token, NoneBefore);
						default:
							noLineEndBefore(token);
					}
				}
				var lastToken:Null<TokenTree> = TokenTreeCheckUtils.getLastToken(token);
				if (lastToken == null) {
					return;
				}
				var next:Null<TokenInfo> = getNextToken(lastToken);
				if (next == null) {
					return;
				}
				switch (next.token.tok) {
					case Kwd(KwdElse):
						noLineEndAfter(lastToken);
					default:
				}
				return;
			case Next:
				switch (token.tok) {
					case CommentLine(s):
						if (!parsedCode.isOriginalNewlineBefore(token)) {
							return;
						}
					default:
				}
				lineEndBefore(token);
		}
	}

	function markDollarSameLine() {
		var tokens:Array<TokenTree> = parsedCode.root.filterCallback(function(token:TokenTree, index:Int):FilterResult {
			return switch (token.tok) {
				case Dollar(_):
					FOUND_SKIP_SUBTREE;
				default:
					GO_DEEPER;
			}
		});
		for (token in tokens) {
			var brOpen:Null<TokenTree> = token.access().firstChild().is(BrOpen).token;
			if (brOpen == null) {
				continue;
			}
			var brClose:TokenTree = brOpen.access().firstOf(BrClose).token;
			if (!parsedCode.isOriginalSameLine(brOpen, brClose)) {
				continue;
			}
			whitespace(brOpen, None);
			var next:Null<TokenInfo> = getNextToken(brClose);
			if (next != null) {
				switch (next.token.tok) {
					case BrClose:
					case POpen, PClose, BkOpen, BkClose:
						whitespace(brClose, None);
					case DblDot:
					case Comma, Semicolon, Dot:
						whitespace(brClose, None);
					default:
						whitespace(brClose, OnlyAfter);
				}
			} else {
				noLineEndAfter(brClose);
			}
			wrapBefore(brOpen, false);
			wrapAfter(brOpen, false);
			wrapBefore(brClose, false);
			wrapAfter(brClose, false);
		}
	}

	function markFunction(token:TokenTree) {
		var body:Null<TokenTree> = token.access().firstChild().isCIdent().token;
		if (body == null) {
			body = token.access().firstChild().is(Kwd(KwdNew)).token;
		}
		var policy:SameLinePolicy = config.sameLine.functionBody;
		if (body == null) {
			body = token;
			policy = config.sameLine.anonFunctionBody;
		}
		if ((body == null) || (body.children == null)) {
			return;
		}
		body = body.access().firstOf(POpen).token;
		if (body == null) {
			return;
		}
		if (body.nextSibling == null) {
			return;
		}
		body = body.nextSibling;
		switch (body.tok) {
			case DblDot:
				body = body.nextSibling;
			default:
		}
		if (body == null) {
			return;
		}
		switch (body.tok) {
			case BrOpen:
				return;
			case Semicolon:
				return;
			case CommentLine(_):
				return;
			default:
		}
		applySameLinePolicy(body, policy);
	}

	function markDoWhile(token:TokenTree) {
		markBody(token, config.sameLine.doWhileBody, false);
		var whileTok:Null<TokenTree> = token.access().firstOf(Kwd(KwdWhile)).token;
		if (whileTok == null) {
			return;
		}
		applySameLinePolicy(whileTok, config.sameLine.doWhile);
	}

	function markMacro(token:TokenTree) {
		var brOpen:Null<TokenInfo> = getNextToken(token);
		if ((brOpen == null) || (!brOpen.token.is(BrOpen))) {
			return;
		}
		var brClose:TokenTree = brOpen.token.access().firstOf(BrClose).token;
		if (parsedCode.isOriginalSameLine(brOpen.token, brClose)) {
			noLineEndAfter(brOpen.token);
			noLineEndBefore(brClose);
			noWrappingBetween(brOpen.token, brClose);
		}
	}

	function markReturn(token:TokenTree) {
		markBody(token, config.sameLine.returnBody, false);
	}
}
