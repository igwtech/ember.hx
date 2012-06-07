package macros;
import ember.Object;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.ExampleJSGenerator;
import haxe.macro.JSGenApi;
import haxe.macro.Type;
import haxe.macro.Expr;
using Lambda;

class EmberJSGenerator extends ExampleJSGenerator {

	public function new(api) {
		super(api);
	}

	/**
	 * TODO: Instead of checking for ember on this specific class, check the whole anscestor tree for it, and if we find
	 * Ember.Object then this counts as an ember class.
	 * 
	 * @param	c
	 */
	override function genClass(c:ClassType) {
		if (c.meta.has(":ember")) {
			genEmberClass(c);
		} else {
			super.genClass(c);
		}
	}
	
	override function genType(t:Type) {
		switch(t) {
			case TInst(c, _):
				var c = c.get();
				if(c.init != null)
					inits.add(c.init);
				if (!c.isExtern) {
					genClass(c);
				}
			case TEnum(r, _):
				var e = r.get();
				if( !e.isExtern ) genEnum(e);
			default:
		}
	}
	
	#if macro
	public static function use() {
		Compiler.setCustomJSGenerator(function(api) new EmberJSGenerator(api).generate());
	}
	#end
	
	private function genEmberClass(c:ClassType) {
		print("/**********************************************************/");
		newline();
		
		genPackage(c.pack);
		api.setCurrentClass(c);
		var p = getPath(c);
		fprint("$p = $$hxClasses['$p'] = ");
		// Commented out the constructor temporarily - it was stopping the root app from initializing
		//if ( c.constructor != null ) {
			var superClassType = c.superClass.t.get();
			
			var jsSuperClass = superClassType.module;
			if (superClassType.meta.has(":native")) {
				for (meta in superClassType.meta.get()) {
					if (meta.name == ":native") {
						jsSuperClass = getStringFromExpr(meta.params[0]);
						break;
					}
				}
			}
			
			print(jsSuperClass + (c.meta.has(":create") ? ".create()" : ".extend()"));
		//} else {
		//	print("function() { }");
		//}
		
		newline();
		
		for( f in c.statics.get() )
			genStaticField(c, p, f);
		for ( f in c.fields.get() ) {
			switch( f.kind ) {
			case FVar(r, _):
				if (r == AccResolve) continue;
			// Don't generate Javascript for inlined methods as there is no point
			case FMethod(f):
				if (f == MethInline) continue;
			default:
			}
			genClassField(c, p, f);
		}
		print("/**********************************************************/");
		newline();
	}
	
	/**
	 * Get a CString out a an Expr (used for getting macros)
	 */
	private function getStringFromExpr(expr:Expr) {
		return
			switch (expr.expr) {
				case EConst(c):
					switch (c) {
						case CString(s): return s;
						default:
					}
					default:
			}
	}
	
	/**
	 * Had to copy this from ExampleJSGenerator since it is static
	 * 
	 * @param	e
	 */
	@:macro static function fprint(e:Expr) {
		var pos = haxe.macro.Context.currentPos();
		var ret = haxe.macro.Format.format(e);
		return { expr : ECall({ expr : EConst(CIdent("print")), pos : pos },[ret]), pos : pos };
	}
	
}