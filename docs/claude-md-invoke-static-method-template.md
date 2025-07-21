# CLAUDE.md Template for invoke_static_method Tool

Add the following content to your project's CLAUDE.md file to enable AI assistants to use the invoke_static_method tool effectively.

---

## MCP Unity Integration

This project has MCP Unity integration enabled, allowing AI assistants to interact with Unity Editor.

### Invoking Static Methods

You can call any static method in Unity using the `invoke_static_method` tool. This is useful for:
- Debugging and logging
- Creating GameObjects programmatically
- Modifying project settings
- Running custom utility methods

#### Basic Usage

```json
{
  "typeName": "FullyQualifiedTypeName",
  "methodName": "MethodName",
  "parameters": [
    {
      "type": "parameterType",
      "value": parameterValue
    }
  ]
}
```

#### Common Examples

1. **Debug Logging**
```json
{
  "typeName": "UnityEngine.Debug",
  "methodName": "Log",
  "parameters": [{"type": "string", "value": "Debug message here"}]
}
```

2. **Create GameObject**
```json
{
  "typeName": "UnityEngine.GameObject",
  "methodName": "CreatePrimitive",
  "parameters": [{"type": "PrimitiveType", "value": "Cube"}]
}
```

3. **Display Dialog**
```json
{
  "typeName": "UnityEditor.EditorUtility",
  "methodName": "DisplayDialog",
  "parameters": [
    {"type": "string", "value": "Title"},
    {"type": "string", "value": "Message"},
    {"type": "string", "value": "OK"}
  ]
}
```

#### Supported Parameter Types
- **Primitives**: string, int, float, double, bool, long
- **Unity Types**: Vector3 `{"x": 0, "y": 0, "z": 0}`, Vector2, Color `{"r": 1, "g": 0, "b": 0, "a": 1}`
- **Arrays**: string[], int[], float[]
- **Enums**: Use string value (e.g., "Cube" for PrimitiveType.Cube)
- **GameObject**: Use the GameObject's name as a string

#### Project-Specific Static Methods

[List any custom static utility methods in your project that might be useful]

Example:
```csharp
// If your project has utility methods like:
public static class GameUtils
{
    public static void ResetGameState() { /* ... */ }
    public static void LoadLevel(string levelName) { /* ... */ }
}
```

You can call them with:
```json
{
  "typeName": "GameUtils",
  "methodName": "LoadLevel",
  "parameters": [{"type": "string", "value": "MainMenu"}]
}
```

### Important Notes

1. **Type Names**: Always use fully qualified type names including namespace (e.g., `UnityEngine.Debug` not just `Debug`)
2. **Method Visibility**: Only public static methods can be invoked
3. **Return Values**: Methods that return values will include the result in the response
4. **Error Handling**: Check the response for error messages if a method call fails
5. **Unity Main Thread**: All methods are executed on Unity's main thread

### Common Tasks Using invoke_static_method

1. **Clear Console**
```json
{
  "typeName": "UnityEditorInternal.InternalEditorUtility",
  "methodName": "ClearConsoleWindow",
  "parameters": []
}
```

2. **Save Project**
```json
{
  "typeName": "UnityEditor.AssetDatabase",
  "methodName": "SaveAssets",
  "parameters": []
}
```

3. **Refresh Asset Database**
```json
{
  "typeName": "UnityEditor.AssetDatabase",
  "methodName": "Refresh",
  "parameters": []
}
```

4. **Set Player Preferences**
```json
{
  "typeName": "UnityEngine.PlayerPrefs",
  "methodName": "SetString",
  "parameters": [
    {"type": "string", "value": "KeyName"},
    {"type": "string", "value": "Value"}
  ]
}
```

### Debugging Tips

- Use `Debug.Log` to output values and track execution
- Check Unity Console for any error messages
- Verify type names and method signatures match exactly
- Remember that Unity must be running with MCP Unity server active

### Advanced Usage

#### Working with Complex Types

For methods that require complex Unity types:

```json
{
  "typeName": "UnityEngine.GameObject",
  "methodName": "Find",
  "parameters": [{"type": "string", "value": "/Canvas/Button"}]
}
```

#### Chaining Operations

While you cannot chain method calls directly, you can use multiple tool invocations:

1. First, create an object:
```json
{
  "typeName": "UnityEngine.GameObject",
  "methodName": "CreatePrimitive",
  "parameters": [{"type": "PrimitiveType", "value": "Sphere"}]
}
```

2. Then modify it using other tools or methods:
```json
{
  "typeName": "UnityEngine.GameObject",
  "methodName": "Find",
  "parameters": [{"type": "string", "value": "Sphere"}]
}
```

#### Error Recovery

If a method call fails:
1. Check the exact type name spelling (case-sensitive)
2. Verify the method is public and static
3. Ensure parameter types match exactly
4. Check Unity Console for detailed error messages

### Limitations

- Only static methods can be invoked (no instance methods)
- Cannot access private or internal methods
- Complex object parameters may need to be passed as simpler types
- Some Unity Editor operations may require specific editor states

### Security Considerations

This tool can execute any public static method. In production:
- Consider restricting which types/methods can be called
- Log all method invocations for audit purposes
- Be cautious with methods that modify project files or settings