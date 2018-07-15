import byte.ByteData;
import haxe.PosInfos;
import haxe.Template;
import massive.munit.Assert;
import tokentreeformatter.config.FormatterConfig;
import tokentreeformatter.codedata.ParseFile;

class GoldBaseTest {
	function goldCheck(unformatted:String, goldCode:String, ?config:FormatterConfig, ?pos:PosInfos) {
		var file:ParseFile = {name: "Test.hx", content: ByteData.ofString(unformatted)};
		var formatter:GoldFormatter = new GoldFormatter(config);
		var formattedCode:String = formatter.formatFile(file);
		Assert.areEqual(goldCode, formattedCode, pos);
	}

	function goldCheckField(unformatted:String, gold:String, ?config:FormatterConfig, ?pos:PosInfos) {
		goldCheckTemplate(FIELD_TEMPLATE, unformatted, gold, config, pos);
	}

	function goldCheckExpr(unformatted:String, gold:String, ?config:FormatterConfig, ?pos:PosInfos) {
		goldCheckTemplate(EXPR_TEMPLATE, unformatted, gold, config, pos);
	}

	function goldCheckTemplate(template:GoldBaseTemplates, unformatted:String, gold:String, ?config:FormatterConfig, ?pos:PosInfos) {
		var template:Template = new Template(template);
		var unformattedFull:String = template.execute({code: unformatted});
		var formattedFull:String = template.execute({code: gold});
		goldCheck(unformattedFull, formattedFull, config, pos);
	}
}

@:enum
abstract GoldBaseTemplates(String) to String {
	var FIELD_TEMPLATE = "class Test {
::code::
}";
	var EXPR_TEMPLATE = "class Test {
	function test() {
		::code::
	}
}";
}