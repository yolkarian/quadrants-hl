import quadrants.Context;
import quadrants.DLPackTensor;
import quadrants.Tensor;
import quadrants.Types.F32;

class TestInteropImportRuntime {
  static function expectFloat(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx:Context) {
      var source:Tensor<F32> = null;
      var pointerImported:Tensor<F32> = null;
      var dlpackImported:Tensor<F32> = null;
      var pointerTarget:Tensor<F32> = null;
      var dlpackTarget:Tensor<F32> = null;
      var dlpack:DLPackTensor = null;
      var secondDLPack:DLPackTensor = null;
      try {
        source = new Tensor<F32>(ctx, [2]);
        source.fromArray([1.5, 2.5]);
        if (!source.supportsExternalPointerImport()) {
          throw 'external_pointer_import_capability';
        }

        pointerImported = new Tensor<F32>(ctx, [2]);
        pointerImported.importExternalPointer(source.exportDevicePointer());
        expectFloat('pointer_import_read', pointerImported.read(1), 2.5);
        pointerImported.write(0, 9.5);
        expectFloat('pointer_import_alias', source.read(0), 9.5);

        dlpack = source.exportDLPack();
        dlpackImported = new Tensor<F32>(ctx, [2]);
        dlpackImported.importDLPack(dlpack);
        dlpack = null;
        expectFloat('dlpack_import_read', dlpackImported.read(0), 9.5);
        dlpackImported.write(1, 7.5);
        expectFloat('dlpack_import_alias', source.read(1), 7.5);

        pointerTarget = new Tensor<F32>(ctx, [2]);
        pointerTarget.importExternalPointer(source.exportDevicePointer());
        pointerTarget.write(1, 11.5);
        expectFloat('pointer_reimport_alias', source.read(1), 11.5);

        secondDLPack = source.exportDLPack();
        dlpackTarget = new Tensor<F32>(ctx, [2]);
        dlpackTarget.importDLPack(secondDLPack);
        secondDLPack = null;
        dlpackTarget.write(0, 13.5);
        expectFloat('dlpack_reimport_alias', source.read(0), 13.5);
      } catch (e:Dynamic) {
        if (dlpack != null) dlpack.close();
        if (secondDLPack != null) secondDLPack.close();
        if (dlpackTarget != null) dlpackTarget.close();
        if (pointerTarget != null) pointerTarget.close();
        if (dlpackImported != null) dlpackImported.close();
        if (pointerImported != null) pointerImported.close();
        if (source != null) source.close();
        throw e;
      }
      if (dlpackTarget != null) dlpackTarget.close();
      if (pointerTarget != null) pointerTarget.close();
      if (dlpackImported != null) dlpackImported.close();
      if (pointerImported != null) pointerImported.close();
      if (source != null) source.close();
    });
  }
}
