package quadrants.macro;

#if macro
import haxe.io.Bytes as HxBytes;
import haxe.macro.Context;
import haxe.macro.Expr;

private typedef ParamInfo = {
  var name:String;
  var kind:Int;
  var rank:Int;
  var dtype:Int;
}

private typedef LocalInfo = {
  var name:String;
  var allocate:Bool;
  var dtype:Int;
}

private class ByteWriter {
  public final bytes:Array<Int> = [];

  public function new() {}

  public function u8(value:Int):Void {
    bytes.push(value & 0xff);
  }

  public function u32(value:Int):Void {
    bytes.push(value & 0xff);
    bytes.push((value >>> 8) & 0xff);
    bytes.push((value >>> 16) & 0xff);
    bytes.push((value >>> 24) & 0xff);
  }

  public function i32(value:Int):Void {
    u32(value);
  }

  public function f64(value:Float):Void {
    var encoded = HxBytes.alloc(8);
    encoded.setDouble(0, value);
    for (i in 0...8) {
      u8(encoded.get(i));
    }
  }

  public function append(other:Array<Int>):Void {
    for (value in other) {
      bytes.push(value);
    }
  }

  public function string(value:String):Void {
    var encoded = HxBytes.ofString(value);
    u32(encoded.length);
    for (i in 0...encoded.length) {
      u8(encoded.get(i));
    }
  }
}

private class DescriptorBuilder {
  static inline var PARAM_UNKNOWN = -1;
  static inline var PARAM_SCALAR = 0;
  static inline var PARAM_NDARRAY = 1;

  static inline var DTYPE_I8 = 0;
  static inline var DTYPE_I16 = 1;
  static inline var DTYPE_I32 = 2;
  static inline var DTYPE_I64 = 3;
  static inline var DTYPE_U8 = 4;
  static inline var DTYPE_U16 = 5;
  static inline var DTYPE_U32 = 6;
  static inline var DTYPE_U64 = 7;
  static inline var DTYPE_F32 = 8;
  static inline var DTYPE_F64 = 9;

  static inline var EXPR_CONST_I32 = 1;
  static inline var EXPR_ARG_LOAD = 2;
  static inline var EXPR_LOCAL_LOAD = 3;
  static inline var EXPR_LOAD_INDEX = 4;
  static inline var EXPR_BINARY_ADD = 5;
  static inline var EXPR_BINARY_SUB = 6;
  static inline var EXPR_BINARY_MUL = 7;
  static inline var EXPR_BINARY_DIV = 8;
  static inline var EXPR_BINARY_MOD = 9;
  static inline var EXPR_CMP_EQ = 10;
  static inline var EXPR_CMP_NE = 11;
  static inline var EXPR_CMP_LT = 12;
  static inline var EXPR_CMP_LE = 13;
  static inline var EXPR_CMP_GT = 14;
  static inline var EXPR_CMP_GE = 15;
  static inline var EXPR_LOGIC_AND = 16;
  static inline var EXPR_LOGIC_OR = 17;
  static inline var EXPR_LOGIC_NOT = 18;
  static inline var EXPR_BIT_AND = 19;
  static inline var EXPR_BIT_OR = 20;
  static inline var EXPR_BIT_XOR = 21;
  static inline var EXPR_SHL = 22;
  static inline var EXPR_SHR = 23;
  static inline var EXPR_SAR = 24;
  static inline var EXPR_CAST = 25;
  static inline var EXPR_UNARY_ABS = 26;
  static inline var EXPR_SIN = 27;
  static inline var EXPR_COS = 28;
  static inline var EXPR_TAN = 29;
  static inline var EXPR_EXP = 30;
  static inline var EXPR_LOG = 31;
  static inline var EXPR_SQRT = 32;
  static inline var EXPR_FLOOR = 33;
  static inline var EXPR_CEIL = 34;
  static inline var EXPR_MIN = 35;
  static inline var EXPR_MAX = 36;
  static inline var EXPR_SELECT = 37;
  static inline var EXPR_UNARY_NEG = 38;
  static inline var EXPR_BIT_NOT = 39;
  static inline var EXPR_CONST_F64 = 40;
  static inline var EXPR_ATOMIC_ADD = 41;

  static inline var STMT_LOCAL_ALLOC = 1;
  static inline var STMT_STORE_INDEX = 2;
  static inline var STMT_RANGE_FOR = 3;
  static inline var STMT_IF = 4;
  static inline var STMT_ASSIGN = 5;
  static inline var STMT_RETURN_VOID = 6;
  static inline var STMT_WHILE = 7;
  static inline var STMT_BREAK = 8;
  static inline var STMT_CONTINUE = 9;
  static inline var STMT_ATOMIC_ADD = 10;
  static inline var STMT_ATOMIC_SUB = 11;

  final params:Array<ParamInfo> = [];
  final paramIds:Map<String, Int> = new Map();
  final locals:Array<LocalInfo> = [];
  final localIds:Map<String, Int> = new Map();
  var loopDepth:Int = 0;

  public function new(args:Array<FunctionArg>) {
    for (arg in args) {
      if (paramIds.exists(arg.name)) {
        Context.error('Duplicate Quadrants kernel parameter ${arg.name}', arg.value == null ? Context.currentPos() : arg.value.pos);
      }
      var typeInfo = parameterTypeInfo(arg.type, arg.value == null ? Context.currentPos() : arg.value.pos);
      paramIds[arg.name] = params.length;
      params.push({name: arg.name, kind: typeInfo.kind, rank: 0, dtype: typeInfo.dtype});
    }
  }

  public function build(functionBody:Expr):Array<Int> {
    var topStatements = statementsOf(functionBody);
    var statementBytes = new ByteWriter();
    for (statement in topStatements) {
      encodeStatement(statement, statementBytes);
    }
    for (param in params) {
      if (param.kind == PARAM_UNKNOWN) {
        param.kind = PARAM_SCALAR;
      }
    }

    var strings:Array<String> = [];
    var stringIds:Map<String, Int> = new Map();
    function intern(value:String):Int {
      var existing = stringIds.get(value);
      if (existing != null) {
        return existing;
      }
      var id = strings.length;
      strings.push(value);
      stringIds[value] = id;
      return id;
    }

    var kernelNameId = intern("haxe_kernel");
    for (param in params) {
      intern(param.name);
    }
    for (local in locals) {
      intern(local.name);
    }

    var stringsSection = new ByteWriter();
    stringsSection.u32(strings.length);
    for (value in strings) {
      stringsSection.string(value);
    }

    var paramsSection = new ByteWriter();
    paramsSection.u32(params.length);
    for (param in params) {
      paramsSection.u8(param.kind);
      paramsSection.u8(param.dtype);
      paramsSection.u8(param.rank);
      paramsSection.u8(0);
      paramsSection.u32(intern(param.name));
    }

    var localsSection = new ByteWriter();
    localsSection.u32(locals.length);
    for (local in locals) {
      localsSection.u8(local.dtype);
      localsSection.u8(local.allocate ? 1 : 0);
      localsSection.u8(0);
      localsSection.u8(0);
      localsSection.u32(intern(local.name));
    }

    var statementsSection = new ByteWriter();
    statementsSection.u32(kernelNameId);
    statementsSection.u32(topStatements.length);
    statementsSection.append(statementBytes.bytes);

    var headerSize = 28;
    var stringsOffset = headerSize;
    var paramsOffset = stringsOffset + stringsSection.bytes.length;
    var localsOffset = paramsOffset + paramsSection.bytes.length;
    var statementsOffset = localsOffset + localsSection.bytes.length;
    var totalSize = statementsOffset + statementsSection.bytes.length;

    var descriptor = new ByteWriter();
    descriptor.u8(0x51);
    descriptor.u8(0x44);
    descriptor.u8(0x48);
    descriptor.u8(0x4c);
    descriptor.u32(1);
    descriptor.u32(stringsOffset);
    descriptor.u32(paramsOffset);
    descriptor.u32(localsOffset);
    descriptor.u32(statementsOffset);
    descriptor.u32(totalSize);
    descriptor.append(stringsSection.bytes);
    descriptor.append(paramsSection.bytes);
    descriptor.append(localsSection.bytes);
    descriptor.append(statementsSection.bytes);
    return descriptor.bytes;
  }

  function encodeStatement(statement:Expr, writer:ByteWriter):Void {
    var expr = strip(statement);
    switch (expr.expr) {
      case EBlock(_):
        for (inner in statementsOf(expr)) {
          encodeStatement(inner, writer);
        }
      case EFor(iterator, body):
        encodeRangeFor(iterator, body, writer, expr.pos);
      case EWhile(condition, body, true):
        encodeWhile(condition, body, writer);
      case EWhile(_, _, false):
        Context.error("Quadrants HashLink does not support do-while loops", expr.pos);
      case EBreak:
        if (loopDepth <= 0) {
          Context.error("Quadrants HashLink break must be inside a loop", expr.pos);
        }
        writer.u8(STMT_BREAK);
      case EContinue:
        if (loopDepth <= 0) {
          Context.error("Quadrants HashLink continue must be inside a loop", expr.pos);
        }
        writer.u8(STMT_CONTINUE);
      case EVars(vars):
        encodeVars(vars, writer, expr.pos);
      case EBinop(OpAssignOp(op), lhs, rhs):
        encodeCompoundAssignment(op, lhs, rhs, writer, expr.pos);
      case EBinop(OpAssign, lhs, rhs):
        encodeAssignment(lhs, rhs, writer, expr.pos);
      case EIf(condition, ifBody, elseBody):
        writer.u8(STMT_IF);
        encodeExpression(condition, writer);
        var ifStatements = statementsOf(ifBody);
        writer.u32(ifStatements.length);
        for (inner in ifStatements) {
          encodeStatement(inner, writer);
        }
        var elseStatements = elseBody == null ? [] : statementsOf(elseBody);
        writer.u32(elseStatements.length);
        for (inner in elseStatements) {
          encodeStatement(inner, writer);
        }
      case EReturn(null):
        writer.u8(STMT_RETURN_VOID);
      default:
        Context.error("Unsupported Quadrants HashLink kernel statement", expr.pos);
    }
  }

  function encodeRangeFor(iterator:Expr, body:Expr, writer:ByteWriter, pos:Position):Void {
    switch (strip(iterator).expr) {
      case EBinop(OpIn, loopVariable, range):
        var loopName = requireIdent(loopVariable, "Quadrants range-for loop variable must be an identifier");
        var rangeExpr = strip(range);
        switch (rangeExpr.expr) {
          case EBinop(OpInterval, begin, end):
            var localId = ensureLocal(loopName, loopVariable.pos, false, DTYPE_I32);
            var bodyStatements = statementsOf(body);
            writer.u8(STMT_RANGE_FOR);
            writer.u32(localId);
            encodeExpression(begin, writer);
            encodeExpression(end, writer);
            writer.u32(bodyStatements.length);
            loopDepth++;
            for (statement in bodyStatements) {
              encodeStatement(statement, writer);
            }
            loopDepth--;
          default:
            Context.error("Quadrants HashLink range-for only supports 0...n style ranges", rangeExpr.pos);
        }
      default:
        Context.error("Quadrants HashLink only supports for (i in start...end)", pos);
    }
  }

  function encodeWhile(condition:Expr, body:Expr, writer:ByteWriter):Void {
    var bodyStatements = statementsOf(body);
    writer.u8(STMT_WHILE);
    encodeExpression(condition, writer);
    writer.u32(bodyStatements.length);
    loopDepth++;
    for (statement in bodyStatements) {
      encodeStatement(statement, writer);
    }
    loopDepth--;
  }

  function encodeVars(vars:Array<Var>, writer:ByteWriter, pos:Position):Void {
    if (vars.length != 1) {
      Context.error("Quadrants HashLink supports one local variable declaration per statement", pos);
    }
    var local = vars[0];
    var localDType = local.type == null ? DTYPE_I32 : dtypeFromComplexType(local.type, pos);
    var localId = ensureLocal(local.name, pos, true, localDType);
    if (local.expr == null) {
      writer.u8(STMT_LOCAL_ALLOC);
      writer.u32(localId);
    } else {
      writer.u8(STMT_ASSIGN);
      writer.u8(EXPR_LOCAL_LOAD);
      writer.u32(localId);
      encodeExpression(local.expr, writer);
    }
  }

  function encodeAssignment(lhs:Expr, rhs:Expr, writer:ByteWriter, pos:Position):Void {
    switch (strip(lhs).expr) {
      case EArray(_, _):
        var access = collectArrayAccess(lhs);
        writer.u8(STMT_STORE_INDEX);
        encodeArrayBase(access.base, writer, access.indices.length);
        writer.u32(access.indices.length);
        for (index in access.indices) {
          encodeExpression(index, writer);
        }
        encodeExpression(rhs, writer);
      case EConst(CIdent(name)):
        var localId = ensureLocalForAssignment(name, lhs.pos);
        writer.u8(STMT_ASSIGN);
        writer.u8(EXPR_LOCAL_LOAD);
        writer.u32(localId);
        encodeExpression(rhs, writer);
      default:
        Context.error("Quadrants HashLink only supports ndarray element or local variable assignments", pos);
    }
  }

  function encodeCompoundAssignment(op:Binop, lhs:Expr, rhs:Expr, writer:ByteWriter, pos:Position):Void {
    switch (strip(lhs).expr) {
      case EArray(_, _) if (op == OpAdd || op == OpSub):
        var access = collectArrayAccess(lhs);
        writer.u8(op == OpAdd ? STMT_ATOMIC_ADD : STMT_ATOMIC_SUB);
        encodeArrayBase(access.base, writer, access.indices.length);
        writer.u32(access.indices.length);
        for (index in access.indices) {
          encodeExpression(index, writer);
        }
        encodeExpression(rhs, writer);
      default:
        encodeAssignment(lhs, {expr: EBinop(op, lhs, rhs), pos: pos}, writer, pos);
    }
  }

  function encodeExpression(expression:Expr, writer:ByteWriter):Void {
    var expr = stripNoCasts(expression);
    switch (expr.expr) {
      case EConst(CInt(value, _)):
        var parsed = Std.parseInt(value);
        if (parsed == null) {
          Context.error('Invalid i32 literal ${value}', expr.pos);
        }
        writer.u8(EXPR_CONST_I32);
        writer.i32(parsed);
      case EConst(CFloat(value, _)):
        var parsed = Std.parseFloat(value);
        if (Math.isNaN(parsed)) {
          Context.error('Invalid f64 literal ${value}', expr.pos);
        }
        writer.u8(EXPR_CONST_F64);
        writer.f64(parsed);
      case EConst(CIdent(name)):
        var localId = localIds.get(name);
        if (localId != null) {
          writer.u8(EXPR_LOCAL_LOAD);
          writer.u32(localId);
        } else {
          var paramId = paramIds.get(name);
          if (paramId == null) {
            Context.error('Unknown Quadrants kernel identifier ${name}', expr.pos);
          }
          markParamScalar(paramId, expr.pos);
          writer.u8(EXPR_ARG_LOAD);
          writer.u32(paramId);
        }
      case EArray(_, _):
        var access = collectArrayAccess(expr);
        writer.u8(EXPR_LOAD_INDEX);
        encodeArrayBase(access.base, writer, access.indices.length);
        writer.u32(access.indices.length);
        for (index in access.indices) {
          encodeExpression(index, writer);
        }
      case EBinop(op, lhs, rhs):
        writer.u8(binaryOpcode(op, expr.pos));
        encodeExpression(lhs, writer);
        encodeExpression(rhs, writer);
      case EUnop(op, _, operand):
        writer.u8(unaryOpcode(op, expr.pos));
        encodeExpression(operand, writer);
      case ECall(callee, args):
        encodeCall(callee, args, writer, expr.pos);
      case ECast(inner, type), ECheckType(inner, type):
        writer.u8(EXPR_CAST);
        writer.u8(dtypeFromComplexType(type, expr.pos));
        encodeExpression(inner, writer);
      case EIf(condition, ifExpr, elseExpr) if (elseExpr != null):
        writer.u8(EXPR_SELECT);
        encodeExpression(condition, writer);
        encodeExpression(ifExpr, writer);
        encodeExpression(elseExpr, writer);
      default:
        Context.error("Unsupported Quadrants HashLink kernel expression", expr.pos);
    }
  }

  function encodeArrayBase(base:Expr, writer:ByteWriter, rank:Int):Void {
    var expr = strip(base);
    switch (expr.expr) {
      case EConst(CIdent(name)):
        var paramId = paramIds.get(name);
        if (paramId == null) {
          Context.error('Quadrants ndarray ${name} is not a kernel parameter', expr.pos);
        }
        markParamNdarray(paramId, rank, expr.pos);
        writer.u8(EXPR_ARG_LOAD);
        writer.u32(paramId);
      default:
        Context.error("Quadrants HashLink only supports direct ndarray parameter indexing", expr.pos);
    }
  }

  function collectArrayAccess(expression:Expr):{base:Expr, indices:Array<Expr>} {
    var indices:Array<Expr> = [];
    var current = strip(expression);
    while (true) {
      switch (current.expr) {
        case EArray(base, index):
          indices.unshift(index);
          current = strip(base);
        default:
          if (indices.length == 0 || indices.length > 8) {
            Context.error("Quadrants ndarray index count is out of range", expression.pos);
          }
          return {base: current, indices: indices};
      }
    }
    throw "unreachable";
  }

  function binaryOpcode(op:Binop, pos:Position):Int {
    return switch (op) {
      case OpAdd: EXPR_BINARY_ADD;
      case OpSub: EXPR_BINARY_SUB;
      case OpMult: EXPR_BINARY_MUL;
      case OpDiv: EXPR_BINARY_DIV;
      case OpMod: EXPR_BINARY_MOD;
      case OpEq: EXPR_CMP_EQ;
      case OpNotEq: EXPR_CMP_NE;
      case OpLt: EXPR_CMP_LT;
      case OpLte: EXPR_CMP_LE;
      case OpGt: EXPR_CMP_GT;
      case OpGte: EXPR_CMP_GE;
      case OpBoolAnd: EXPR_LOGIC_AND;
      case OpBoolOr: EXPR_LOGIC_OR;
      case OpAnd: EXPR_BIT_AND;
      case OpOr: EXPR_BIT_OR;
      case OpXor: EXPR_BIT_XOR;
      case OpShl: EXPR_SHL;
      case OpShr: EXPR_SAR;
      case OpUShr: EXPR_SHR;
      default: Context.error("Unsupported Quadrants HashLink binary operator", pos);
    }
  }

  function unaryOpcode(op:Unop, pos:Position):Int {
    return switch (op) {
      case OpNot: EXPR_LOGIC_NOT;
      case OpNeg: EXPR_UNARY_NEG;
      case OpNegBits: EXPR_BIT_NOT;
      default: Context.error("Unsupported Quadrants HashLink unary operator", pos);
    }
  }

  function encodeCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    var name = callName(callee, pos);
    if (name == "atomicAdd") {
      encodeAtomicAdd(args, writer, pos);
      return;
    }
    var opcode = switch (name) {
      case "abs": EXPR_UNARY_ABS;
      case "sin": EXPR_SIN;
      case "cos": EXPR_COS;
      case "tan": EXPR_TAN;
      case "exp": EXPR_EXP;
      case "log": EXPR_LOG;
      case "sqrt": EXPR_SQRT;
      case "floor": EXPR_FLOOR;
      case "ceil": EXPR_CEIL;
      case "min": EXPR_MIN;
      case "max": EXPR_MAX;
      default: Context.error('Unsupported Quadrants HashLink function call ${name}', pos);
    };
    var arity = (opcode == EXPR_MIN || opcode == EXPR_MAX) ? 2 : 1;
    if (args.length != arity) {
      Context.error('Quadrants HashLink function ${name} expects ${arity} argument(s)', pos);
    }
    writer.u8(opcode);
    for (arg in args) {
      encodeExpression(arg, writer);
    }
  }

  function encodeAtomicAdd(args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 2) {
      Context.error("Quadrants HashLink function atomicAdd expects 2 argument(s)", pos);
    }
    switch (strip(args[0]).expr) {
      case EArray(_, _):
      default:
        Context.error("Quadrants HashLink atomicAdd target must be an ndarray element", args[0].pos);
    }
    var access = collectArrayAccess(args[0]);
    writer.u8(EXPR_ATOMIC_ADD);
    encodeArrayBase(access.base, writer, access.indices.length);
    writer.u32(access.indices.length);
    for (index in access.indices) {
      encodeExpression(index, writer);
    }
    encodeExpression(args[1], writer);
  }

  function callName(callee:Expr, pos:Position):String {
    var expr = strip(callee);
    return switch (expr.expr) {
      case EConst(CIdent(name)): name;
      case EField(_, field): field;
      default: Context.error("Unsupported Quadrants HashLink function callee", pos);
    };
  }

  function markParamScalar(paramId:Int, pos:Position):Void {
    var param = params[paramId];
    if (param.kind == PARAM_NDARRAY) {
      Context.error('Quadrants parameter ${param.name} is used as both ndarray and scalar', pos);
    }
    param.kind = PARAM_SCALAR;
    param.rank = 0;
  }

  function markParamNdarray(paramId:Int, rank:Int, pos:Position):Void {
    var param = params[paramId];
    if (param.kind == PARAM_SCALAR) {
      Context.error('Quadrants parameter ${param.name} is used as both scalar and ndarray', pos);
    }
    if (param.kind == PARAM_NDARRAY && param.rank != 0 && param.rank != rank) {
      Context.error('Quadrants ndarray parameter ${param.name} is used with inconsistent rank', pos);
    }
    param.kind = PARAM_NDARRAY;
    param.rank = rank;
  }

  function ensureLocal(name:String, pos:Position, allocate:Bool, dtype:Int):Int {
    if (paramIds.exists(name)) {
      Context.error('Quadrants local variable ${name} shadows a kernel parameter', pos);
    }
    var existing = localIds.get(name);
    if (existing != null) {
      if (allocate) {
        locals[existing].allocate = true;
        locals[existing].dtype = dtype;
      }
      return existing;
    }
    var id = locals.length;
    localIds[name] = id;
    locals.push({name: name, allocate: allocate, dtype: dtype});
    return id;
  }

  function ensureLocalForAssignment(name:String, pos:Position):Int {
    var existing = localIds.get(name);
    if (existing != null) {
      return existing;
    }
    return ensureLocal(name, pos, true, DTYPE_I32);
  }

  function statementsOf(expression:Expr):Array<Expr> {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EBlock(expressions): flattenBlocks(expressions);
      case EReturn(returned) if (returned != null): statementsOf(returned);
      default: [expr];
    }
  }

  function flattenBlocks(expressions:Array<Expr>):Array<Expr> {
    var result:Array<Expr> = [];
    for (expression in expressions) {
      var expr = strip(expression);
      switch (expr.expr) {
        case EBlock(inner):
          for (nested in flattenBlocks(inner)) {
            result.push(nested);
          }
        case EReturn(returned) if (returned != null):
          for (nested in statementsOf(returned)) {
            result.push(nested);
          }
        default:
          result.push(expr);
      }
    }
    return result;
  }

  function requireIdent(expression:Expr, message:String):String {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EConst(CIdent(name)): name;
      default: Context.error(message, expr.pos);
    }
  }

  function parameterTypeInfo(type:Null<ComplexType>, pos:Position):{kind:Int, dtype:Int} {
    if (type == null) {
      return {kind: PARAM_UNKNOWN, dtype: DTYPE_I32};
    }
    return switch (type) {
      case TPath(path) if (isTensorPath(path)):
        {kind: PARAM_NDARRAY, dtype: tensorElementDType(path, pos)};
      default:
        {kind: PARAM_UNKNOWN, dtype: dtypeFromComplexType(type, pos)};
    }
  }

  function isTensorPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "Tensor" || fullName == "quadrants.Tensor";
  }

  function tensorElementDType(path:TypePath, pos:Position):Int {
    if (path.params == null || path.params.length == 0) {
      return DTYPE_I32;
    }
    return switch (path.params[0]) {
      case TPType(type): dtypeFromComplexType(type, pos, DTYPE_F32);
      default: Context.error("Quadrants Tensor type parameter must be a type", pos);
    }
  }

  function typePathName(path:TypePath):String {
    return (path.pack.length == 0 ? "" : path.pack.join(".") + ".") + path.name + (path.sub == null ? "" : "." + path.sub);
  }

  function dtypeFromComplexType(type:Null<ComplexType>, pos:Position, floatDType:Int = DTYPE_F64):Int {
    if (type == null) {
      Context.error("Quadrants HashLink cast requires an explicit target type", pos);
    }
    return switch (type) {
      case TPath(path):
        var fullName = typePathName(path);
        switch (fullName) {
          case "Int": DTYPE_I32;
          case "UInt": DTYPE_U32;
          case "haxe.Int64", "Int64": DTYPE_I64;
          case "Float": floatDType;
          case "hl.F32", "F32": DTYPE_F32;
          case "quadrants.I8", "quadrants.Types.I8", "Types.I8", "I8": DTYPE_I8;
          case "quadrants.I16", "quadrants.Types.I16", "Types.I16", "I16": DTYPE_I16;
          case "quadrants.I32", "quadrants.Types.I32", "Types.I32", "I32": DTYPE_I32;
          case "quadrants.I64", "quadrants.Types.I64", "Types.I64", "I64": DTYPE_I64;
          case "quadrants.U8", "quadrants.Types.U8", "Types.U8", "U8": DTYPE_U8;
          case "quadrants.U16", "quadrants.Types.U16", "Types.U16", "U16": DTYPE_U16;
          case "quadrants.U32", "quadrants.Types.U32", "Types.U32", "U32": DTYPE_U32;
          case "quadrants.U64", "quadrants.Types.U64", "Types.U64", "U64": DTYPE_U64;
          case "quadrants.F32", "quadrants.Types.F32", "Types.F32": DTYPE_F32;
          case "quadrants.F64", "quadrants.Types.F64", "Types.F64", "F64": DTYPE_F64;
          default: Context.error('Unsupported Quadrants HashLink dtype ${fullName}', pos);
        }
      default:
        Context.error("Unsupported Quadrants HashLink dtype", pos);
    }
  }

  static function stripNoCasts(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner): stripNoCasts(inner);
      default: expression;
    }
  }

  public static function strip(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner), ECheckType(inner, _), ECast(inner, _): strip(inner);
      default: expression;
    }
  }
}

class KernelBuilder {
  public static function build(ctx:Expr, fn:Expr):Expr {
    var functionExpr = unwrapMacroQuote(fn);
    var functionDef = switch (functionExpr.expr) {
      case EFunction(_, f): f;
      default: Context.error("quadrants.Kernel.build expects a macro arrow function", functionExpr.pos);
    };
    if (functionDef.expr == null) {
      Context.error("Quadrants HashLink kernel function must have a body", functionExpr.pos);
    }

    var builder = new DescriptorBuilder(functionDef.args);
    var descriptorBytes = builder.build(functionDef.expr);
    var descriptorExpr = bytesExpression(descriptorBytes, functionExpr.pos);
    return macro quadrants.Kernel.fromDescriptor($e{ctx}, $e{descriptorExpr}, $v{descriptorBytes.length});
  }

  static function unwrapMacroQuote(expression:Expr):Expr {
    var expr = DescriptorBuilder.strip(expression);
    return switch (expr.expr) {
      case ECall({expr: EConst(CIdent("macro"))}, [quoted]): DescriptorBuilder.strip(quoted);
      case EObjectDecl(_): decodeQuotedExpr(expr);
      default: expr;
    };
  }

  static function decodeQuotedExpr(source:Expr):Expr {
    var exprField = objectField(source, "expr");
    if (exprField == null) {
      Context.error("Invalid quoted Haxe expression", source.pos);
    }
    var meta = constructorParts(exprField);
    if (meta != null && meta.name == "EMeta" && meta.params.length == 2) {
      return decodeQuotedExpr(meta.params[1]);
    }
    return {expr: decodeQuotedExprDef(exprField), pos: source.pos};
  }

  static function decodeQuotedExprDef(source:Expr):ExprDef {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Invalid quoted Haxe expression node", source.pos);
    }
    return switch (parts.name) {
      case "EConst":
        EConst(decodeQuotedConstant(parts.params[0]));
      case "EArray":
        EArray(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]));
      case "EBinop":
        EBinop(decodeQuotedBinop(parts.params[0]), decodeQuotedExpr(parts.params[1]), decodeQuotedExpr(parts.params[2]));
      case "EUnop":
        EUnop(decodeQuotedUnop(parts.params[0]), boolLiteral(parts.params[1]), decodeQuotedExpr(parts.params[2]));
      case "ECall":
        ECall(decodeQuotedExpr(parts.params[0]), [for (item in arrayElements(parts.params[1])) decodeQuotedExpr(item)]);
      case "EField":
        EField(decodeQuotedExpr(parts.params[0]), stringLiteral(parts.params[1]));
      case "ECast":
        ECast(decodeQuotedExpr(parts.params[0]),
            parts.params.length >= 2 && !isNullLiteral(parts.params[1]) ? decodeQuotedComplexType(parts.params[1]) : null);
      case "ECheckType":
        ECheckType(decodeQuotedExpr(parts.params[0]), decodeQuotedComplexType(parts.params[1]));
      case "EBlock":
        EBlock([for (item in arrayElements(parts.params[0])) decodeQuotedExpr(item)]);
      case "EFor":
        EFor(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]));
      case "EWhile":
        EWhile(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]), boolLiteral(parts.params[2]));
      case "EBreak":
        EBreak;
      case "EContinue":
        EContinue;
      case "EVars":
        EVars([for (item in arrayElements(parts.params[0])) decodeQuotedVar(item)]);
      case "EIf":
        EIf(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]),
            parts.params.length >= 3 && !isNullLiteral(parts.params[2]) ? decodeQuotedExpr(parts.params[2]) : null);
      case "EReturn":
        if (parts.params.length == 0 || isNullLiteral(parts.params[0])) {
          EReturn(null);
        } else {
          EReturn(decodeQuotedExpr(parts.params[0]));
        }
      case "EFunction":
        EFunction(decodeQuotedFunctionKind(parts.params[0]), decodeQuotedFunction(parts.params[1]));
      case "EParenthesis":
        EParenthesis(decodeQuotedExpr(parts.params[0]));
      default:
        Context.error('Unsupported quoted Haxe expression node ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedFunction(source:Expr):Function {
    var argsExpr = objectField(source, "args");
    if (argsExpr == null) {
      Context.error("Quoted Haxe function is missing args", source.pos);
    }
    var bodyExpr = objectField(source, "expr");
    var body = bodyExpr == null || isNullLiteral(bodyExpr) ? null : decodeQuotedExpr(bodyExpr);
    return {
      args: [for (arg in arrayElements(argsExpr)) decodeQuotedFunctionArg(arg)],
      ret: null,
      expr: body,
      params: null,
    };
  }

  static function decodeQuotedFunctionArg(source:Expr):FunctionArg {
    var nameExpr = objectField(source, "name");
    if (nameExpr == null) {
      Context.error("Quoted Haxe function argument is missing a name", source.pos);
    }
    var optExpr = objectField(source, "opt");
    var typeExpr = objectField(source, "type");
    return {
      name: stringLiteral(nameExpr),
      opt: optExpr == null ? false : boolLiteral(optExpr),
      type: typeExpr == null || isNullLiteral(typeExpr) ? null : decodeQuotedComplexType(typeExpr),
      value: null,
      meta: null,
    };
  }

  static function decodeQuotedVar(source:Expr):Var {
    var nameExpr = objectField(source, "name");
    if (nameExpr == null) {
      Context.error("Quoted Haxe variable is missing a name", source.pos);
    }
    var expr = objectField(source, "expr");
    var typeExpr = objectField(source, "type");
    return {
      name: stringLiteral(nameExpr),
      type: typeExpr == null || isNullLiteral(typeExpr) ? null : decodeQuotedComplexType(typeExpr),
      expr: expr == null || isNullLiteral(expr) ? null : decodeQuotedExpr(expr),
      isFinal: false,
      meta: null,
    };
  }

  static function decodeQuotedFunctionKind(source:Expr):Null<FunctionKind> {
    return switch (constructorName(source)) {
      case "FArrow": FArrow;
      case "FAnonymous": FAnonymous;
      case "null": null;
      case other: Context.error('Unsupported quoted Haxe function kind ${other}', source.pos);
    };
  }

  static function decodeQuotedComplexType(source:Expr):ComplexType {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Invalid quoted Haxe complex type", source.pos);
    }
    return switch (parts.name) {
      case "TPath": TPath(decodeQuotedTypePath(parts.params[0]));
      default: Context.error('Unsupported quoted Haxe complex type ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedTypePath(source:Expr):TypePath {
    var nameExpr = objectField(source, "name");
    if (nameExpr == null) {
      Context.error("Quoted Haxe type path is missing a name", source.pos);
    }
    var packExpr = objectField(source, "pack");
    var paramsExpr = objectField(source, "params");
    var subExpr = objectField(source, "sub");
    return {
      pack: packExpr == null ? [] : [for (item in arrayElements(packExpr)) stringLiteral(item)],
      name: stringLiteral(nameExpr),
      params: paramsExpr == null ? [] : [for (item in arrayElements(paramsExpr)) decodeQuotedTypeParam(item)],
      sub: subExpr == null || isNullLiteral(subExpr) ? null : stringLiteral(subExpr),
    };
  }

  static function decodeQuotedTypeParam(source:Expr):TypeParam {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Invalid quoted Haxe type parameter", source.pos);
    }
    return switch (parts.name) {
      case "TPType": TPType(decodeQuotedComplexType(parts.params[0]));
      case "TPExpr": TPExpr(decodeQuotedExpr(parts.params[0]));
      default: Context.error('Unsupported quoted Haxe type parameter ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedConstant(source:Expr):Constant {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Invalid quoted Haxe constant", source.pos);
    }
    return switch (parts.name) {
      case "CInt": CInt(stringLiteral(parts.params[0]), null);
      case "CFloat": CFloat(stringLiteral(parts.params[0]), null);
      case "CIdent": CIdent(stringLiteral(parts.params[0]));
      case "CString": CString(stringLiteral(parts.params[0]));
      default: Context.error('Unsupported quoted Haxe constant ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedBinop(source:Expr):Binop {
    var parts = constructorParts(source);
    if (parts != null && parts.name == "OpAssignOp") {
      return OpAssignOp(decodeQuotedBinop(parts.params[0]));
    }
    return switch (constructorName(source)) {
      case "OpAdd": OpAdd;
      case "OpSub": OpSub;
      case "OpMult": OpMult;
      case "OpDiv": OpDiv;
      case "OpMod": OpMod;
      case "OpEq": OpEq;
      case "OpNotEq": OpNotEq;
      case "OpLt": OpLt;
      case "OpLte": OpLte;
      case "OpGt": OpGt;
      case "OpGte": OpGte;
      case "OpBoolAnd": OpBoolAnd;
      case "OpBoolOr": OpBoolOr;
      case "OpAnd": OpAnd;
      case "OpOr": OpOr;
      case "OpXor": OpXor;
      case "OpShl": OpShl;
      case "OpShr": OpShr;
      case "OpUShr": OpUShr;
      case "OpAssign": OpAssign;
      case "OpInterval": OpInterval;
      case "OpIn": OpIn;
      case other: Context.error('Unsupported quoted Haxe binary operator ${other}', source.pos);
    };
  }

  static function decodeQuotedUnop(source:Expr):Unop {
    return switch (constructorName(source)) {
      case "OpNot": OpNot;
      case "OpNeg": OpNeg;
      case "OpNegBits": OpNegBits;
      case "OpIncrement": OpIncrement;
      case "OpDecrement": OpDecrement;
      case other: Context.error('Unsupported quoted Haxe unary operator ${other}', source.pos);
    };
  }

  static function constructorName(source:Expr):String {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EConst(CIdent(name)): name;
      case EField(_, field): field;
      default: Context.error("Invalid quoted Haxe enum constructor", source.pos);
    };
  }

  static function constructorParts(source:Expr):Null<{name:String, params:Array<Expr>}> {
    var expr = DescriptorBuilder.strip(source);
    return switch (expr.expr) {
      case ECall(callee, params): {name: constructorName(callee), params: params};
      case EConst(CIdent(_)) | EField(_, _): {name: constructorName(expr), params: []};
      default: null;
    };
  }

  static function objectField(source:Expr, name:String):Null<Expr> {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EObjectDecl(fields):
        for (field in fields) {
          if (field.field == name) {
            return field.expr;
          }
        }
        null;
      default:
        Context.error("Invalid quoted Haxe object", source.pos);
    };
  }

  static function arrayElements(source:Expr):Array<Expr> {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EArrayDecl(values): values;
      default: Context.error("Invalid quoted Haxe array", source.pos);
    };
  }

  static function stringLiteral(source:Expr):String {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EConst(CString(value, _)): value;
      default: Context.error("Expected quoted Haxe string literal", source.pos);
    };
  }

  static function boolLiteral(source:Expr):Bool {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EConst(CIdent("true")): true;
      case EConst(CIdent("false")): false;
      default: Context.error("Expected quoted Haxe bool literal", source.pos);
    };
  }

  static function isNullLiteral(source:Expr):Bool {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EConst(CIdent("null")): true;
      default: false;
    };
  }

  static function bytesExpression(bytes:Array<Int>, pos:Position):Expr {
    var expressions:Array<Expr> = [];
    expressions.push(macro var descriptor = new hl.Bytes($v{bytes.length}));
    for (i in 0...bytes.length) {
      expressions.push(macro descriptor.setUI8($v{i}, $v{bytes[i]}));
    }
    expressions.push(macro descriptor);
    return {expr: EBlock(expressions), pos: pos};
  }
}
#end
