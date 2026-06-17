package quadrants.macro;

#if macro
class DescriptorV2Writer {
  public static function autoMetadata(kernelName:String, params:Array<Dynamic>):String {
    return DescriptorWriter.autoMetadata(kernelName, params);
  }

  public static function attributesSection(metadataJson:String):Array<Int> {
    return DescriptorWriter.attributesSection(metadataJson);
  }
}
#end
