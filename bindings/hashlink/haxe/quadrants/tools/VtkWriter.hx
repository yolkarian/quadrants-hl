package quadrants.tools;

import haxe.Int64;
import haxe.io.FPHelper;
import haxe.io.Output;
import sys.io.File;

private typedef ValidatedVtkGrid = {
  var x:Int;
  var y:Int;
  var z:Int;
  var pointCount:Int;
  var originX:Float;
  var originY:Float;
  var originZ:Float;
  var spacingX:Float;
  var spacingY:Float;
  var spacingZ:Float;
}

/**
  Writes scalar grids as self-contained VTK legacy 3.0 ASCII
  `STRUCTURED_POINTS` datasets; no Python package or native writer is used.

  `shape` uses VTK axis order `[x, y]` or `[x, y, z]`. Values must contain
  exactly `x * y` or `x * y * z` elements in VTK point order, with x varying
  fastest: `x + sizeX * (y + sizeY * z)`. A 2-D grid is written as
  `DIMENSIONS x y 1`, with z origin `0` and z spacing `1`.
*/
class VtkWriter {
  public static inline var DEFAULT_TITLE = "Quadrants scalar grid";

  public static function write(
    path:String,
    values:VtkScalarData,
    shape:Array<Int>,
    origin:Array<Float>,
    spacing:Array<Float>,
    scalarName:String = "scalars",
    title:String = DEFAULT_TITLE):Void {
    var grid = validateGrid(values, shape, origin, spacing, scalarName, title);
    writeToPath(path, function(output:Output):Void {
      output.writeString(header(grid, values, scalarName, title));
      writeValues(output, values, grid.pointCount);
    });
  }

  private static function header(grid:ValidatedVtkGrid, values:VtkScalarData, scalarName:String, title:String):String {
    var output = new StringBuf();
    output.add("# vtk DataFile Version 3.0\n");
    output.add(title);
    output.add("\nASCII\n");
    output.add("DATASET STRUCTURED_POINTS\n");
    output.add("DIMENSIONS ");
    output.add(Std.string(grid.x));
    output.add(" ");
    output.add(Std.string(grid.y));
    output.add(" ");
    output.add(Std.string(grid.z));
    output.add("\nORIGIN ");
    output.add(formatFloat64(grid.originX));
    output.add(" ");
    output.add(formatFloat64(grid.originY));
    output.add(" ");
    output.add(formatFloat64(grid.originZ));
    output.add("\nSPACING ");
    output.add(formatFloat64(grid.spacingX));
    output.add(" ");
    output.add(formatFloat64(grid.spacingY));
    output.add(" ");
    output.add(formatFloat64(grid.spacingZ));
    output.add("\nPOINT_DATA ");
    output.add(Std.string(grid.pointCount));
    output.add("\nSCALARS ");
    output.add(scalarName);
    output.add(" ");
    output.add(scalarTypeName(values));
    output.add(" 1\nLOOKUP_TABLE default\n");
    return output.toString();
  }

  private static function writeValues(output:Output, values:VtkScalarData, pointCount:Int):Void {
    for (index in 0...pointCount) {
      output.writeString(scalarAsAscii(values, index));
      output.writeByte(10);
    }
  }

  private static function validateGrid(
    values:VtkScalarData,
    shape:Array<Int>,
    origin:Array<Float>,
    spacing:Array<Float>,
    scalarName:String,
    title:String):ValidatedVtkGrid {
    if (shape == null || (shape.length != 2 && shape.length != 3)) {
      throw "VtkWriter shape must have rank 2 or 3";
    }
    if (origin == null || origin.length != shape.length) {
      throw "VtkWriter origin rank must match shape rank";
    }
    if (spacing == null || spacing.length != shape.length) {
      throw "VtkWriter spacing rank must match shape rank";
    }
    validateScalarName(scalarName);
    validateTitle(title);

    var pointCount = checkedElementCount(shape);
    validateScalarData(values, pointCount);
    for (axis in 0...shape.length) {
      validateFinite(origin[axis], 'origin[${axis}]');
      validateFinite(spacing[axis], 'spacing[${axis}]');
      if (spacing[axis] <= 0.0) {
        throw 'VtkWriter spacing[${axis}] must be positive';
      }
    }

    return {
      x: shape[0],
      y: shape[1],
      z: shape.length == 3 ? shape[2] : 1,
      pointCount: pointCount,
      originX: origin[0],
      originY: origin[1],
      originZ: shape.length == 3 ? origin[2] : 0.0,
      spacingX: spacing[0],
      spacingY: spacing[1],
      spacingZ: shape.length == 3 ? spacing[2] : 1.0,
    };
  }

  private static function checkedElementCount(shape:Array<Int>):Int {
    var count = 1;
    for (axis in 0...shape.length) {
      var dimension = shape[axis];
      if (dimension <= 0) {
        throw 'VtkWriter shape[${axis}] must be positive';
      }
      if (count > Std.int(0x7fffffff / dimension)) {
        throw "VtkWriter shape element count exceeds the Haxe array limit";
      }
      count *= dimension;
    }
    return count;
  }

  private static function scalarTypeName(values:VtkScalarData):String {
    return switch (values) {
      case VtkScalarData.Int8(_): "char";
      case VtkScalarData.UInt8(_): "unsigned_char";
      case VtkScalarData.Int16(_): "short";
      case VtkScalarData.UInt16(_): "unsigned_short";
      case VtkScalarData.Int32(_): "int";
      case VtkScalarData.UInt32(_): "unsigned_int";
      case VtkScalarData.Float32(_): "float";
      case VtkScalarData.Float64(_): "double";
    };
  }

  private static function scalarAsAscii(values:VtkScalarData, index:Int):String {
    return switch (values) {
      case VtkScalarData.Int8(data) | VtkScalarData.UInt8(data) | VtkScalarData.Int16(data) | VtkScalarData.UInt16(data) | VtkScalarData.Int32(data):
        Std.string(data[index]);
      case VtkScalarData.UInt32(data):
        Int64.toStr(data[index]);
      case VtkScalarData.Float32(data):
        Std.string(FPHelper.i32ToFloat(FPHelper.floatToI32(data[index])));
      case VtkScalarData.Float64(data):
        formatFloat64(data[index]);
    };
  }

  private static function validateScalarData(values:VtkScalarData, expectedCount:Int):Void {
    if (values == null) {
      throw "VtkWriter scalar values are required";
    }
    switch (values) {
      case VtkScalarData.Int8(data):
        validateIntRange(data, expectedCount, -128, 127, "char");
      case VtkScalarData.UInt8(data):
        validateIntRange(data, expectedCount, 0, 255, "unsigned_char");
      case VtkScalarData.Int16(data):
        validateIntRange(data, expectedCount, -32768, 32767, "short");
      case VtkScalarData.UInt16(data):
        validateIntRange(data, expectedCount, 0, 65535, "unsigned_short");
      case VtkScalarData.Int32(data):
        validateIntRange(data, expectedCount, -2147483648, 2147483647, "int");
      case VtkScalarData.UInt32(data):
        validateUInt32(data, expectedCount);
      case VtkScalarData.Float32(data):
        validateFloatData(data, expectedCount, true);
      case VtkScalarData.Float64(data):
        validateFloatData(data, expectedCount, false);
    }
  }

  private static function validateIntRange(data:Array<Int>, expectedCount:Int, minimum:Int, maximum:Int, vtkType:String):Void {
    if (data == null || data.length != expectedCount) {
      throw 'VtkWriter ${vtkType} scalar length must be ${expectedCount}';
    }
    for (value in data) {
      if (value < minimum || value > maximum) {
        throw 'VtkWriter ${vtkType} scalar ${value} is outside [${minimum}, ${maximum}]';
      }
    }
  }

  private static function validateUInt32(data:Array<Int64>, expectedCount:Int):Void {
    if (data == null || data.length != expectedCount) {
      throw 'VtkWriter unsigned_int scalar length must be ${expectedCount}';
    }
    var zero = Int64.ofInt(0);
    var maximum = Int64.make(0, -1);
    for (value in data) {
      if (Int64.compare(value, zero) < 0 || Int64.compare(value, maximum) > 0) {
        throw 'VtkWriter unsigned_int scalar ${Int64.toStr(value)} is outside [0, 4294967295]';
      }
    }
  }

  private static function validateFloatData(data:Array<Float>, expectedCount:Int, singlePrecision:Bool):Void {
    if (data == null || data.length != expectedCount) {
      throw 'VtkWriter floating scalar length must be ${expectedCount}';
    }
    for (value in data) {
      validateFinite(value, "scalar value");
      if (singlePrecision && !Math.isFinite(FPHelper.i32ToFloat(FPHelper.floatToI32(value)))) {
        throw "VtkWriter float scalar overflows VTK float";
      }
    }
  }

  private static function validateFinite(value:Float, label:String):Void {
    if (!Math.isFinite(value)) {
      throw 'VtkWriter ${label} must be finite';
    }
  }

  private static function validateScalarName(value:String):Void {
    if (value == null || value.length == 0 || !isIdentifier(value)) {
      throw "VtkWriter scalarName must be an ASCII identifier";
    }
  }

  private static function validateTitle(value:String):Void {
    if (value == null || value.length == 0 || value.length > 255) {
      throw "VtkWriter title must contain 1 to 255 ASCII characters";
    }
    for (index in 0...value.length) {
      var code = StringTools.fastCodeAt(value, index);
      if (code < 32 || code > 126) {
        throw "VtkWriter title must contain only printable ASCII characters";
      }
    }
  }

  private static function isIdentifier(value:String):Bool {
    for (index in 0...value.length) {
      var code = StringTools.fastCodeAt(value, index);
      var letter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
      var digit = code >= 48 && code <= 57;
      if (index == 0 ? !(letter || code == 95) : !(letter || digit || code == 95)) {
        return false;
      }
    }
    return true;
  }

  private static function formatFloat64(value:Float):String {
    return Std.string(value);
  }

  private static function writeToPath(path:String, write:Output->Void):Void {
    if (path == null || path.length == 0) {
      throw "VtkWriter output path is required";
    }
    var output = File.write(path, true);
    try {
      write(output);
      output.close();
    } catch (error:Dynamic) {
      try {
        output.close();
      } catch (_:Dynamic) {}
      throw error;
    }
  }
}
