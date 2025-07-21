using System;
using System.Linq;
using System.Reflection;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Newtonsoft.Json.Linq;
using McpUnity.Unity;
using McpUnity.Utils;

namespace McpUnity.Tools
{
    /// <summary>
    /// Tool for invoking arbitrary static methods with parameters
    /// </summary>
    public class InvokeStaticMethodTool : McpToolBase
    {
        public InvokeStaticMethodTool()
        {
            Name = "invoke_static_method";
            Description = "Invokes any static method with specified parameters";
            IsAsync = false;
        }
        
        public override JObject Execute(JObject parameters)
        {
            try
            {
                // Extract parameters
                string typeName = parameters["typeName"]?.ToObject<string>();
                string methodName = parameters["methodName"]?.ToObject<string>();
                JArray methodParams = parameters["parameters"] as JArray;
                
                // Validation
                if (string.IsNullOrEmpty(typeName))
                {
                    return CreateErrorResponse("Required parameter 'typeName' not provided");
                }
                
                if (string.IsNullOrEmpty(methodName))
                {
                    return CreateErrorResponse("Required parameter 'methodName' not provided");
                }
                
                // Find the type
                Type targetType = FindType(typeName);
                if (targetType == null)
                {
                    return CreateErrorResponse($"Type '{typeName}' not found");
                }
                
                // Prepare method parameters
                object[] methodArgs = null;
                Type[] paramTypes = null;
                
                if (methodParams != null && methodParams.Count > 0)
                {
                    methodArgs = new object[methodParams.Count];
                    paramTypes = new Type[methodParams.Count];
                    
                    for (int i = 0; i < methodParams.Count; i++)
                    {
                        var param = methodParams[i] as JObject;
                        if (param == null)
                        {
                            return CreateErrorResponse($"Parameter at index {i} is not an object");
                        }
                        
                        string paramType = param["type"]?.ToObject<string>();
                        JToken paramValue = param["value"];
                        
                        if (string.IsNullOrEmpty(paramType))
                        {
                            return CreateErrorResponse($"Parameter at index {i} missing 'type'");
                        }
                        
                        // Convert parameter
                        var converted = ConvertParameter(paramType, paramValue);
                        if (!converted.success)
                        {
                            return CreateErrorResponse($"Parameter at index {i}: {converted.error}");
                        }
                        
                        methodArgs[i] = converted.value;
                        paramTypes[i] = converted.type;
                    }
                }
                else
                {
                    methodArgs = new object[0];
                    paramTypes = Type.EmptyTypes;
                }
                
                // Find the method
                MethodInfo method = targetType.GetMethod(
                    methodName, 
                    BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static,
                    null,
                    paramTypes,
                    null
                );
                
                if (method == null)
                {
                    // Try to find method without exact parameter matching
                    var methods = targetType.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static)
                        .Where(m => m.Name == methodName)
                        .ToArray();
                    
                    if (methods.Length == 0)
                    {
                        return CreateErrorResponse($"Static method '{methodName}' not found in type '{typeName}'");
                    }
                    
                    if (methods.Length > 1)
                    {
                        var signatures = string.Join("\n", methods.Select(m => 
                            $"- {m.Name}({string.Join(", ", m.GetParameters().Select(p => p.ParameterType.Name))})"));
                        return CreateErrorResponse($"Multiple overloads found for '{methodName}':\n{signatures}");
                    }
                    
                    method = methods[0];
                    
                    // Try to convert parameters to match method signature
                    var methodParameters = method.GetParameters();
                    if (methodParameters.Length != methodArgs.Length)
                    {
                        return CreateErrorResponse($"Method '{methodName}' expects {methodParameters.Length} parameters, but {methodArgs.Length} provided");
                    }
                    
                    // Convert parameters to match expected types
                    for (int i = 0; i < methodArgs.Length; i++)
                    {
                        try
                        {
                            if (methodArgs[i] != null && !methodParameters[i].ParameterType.IsAssignableFrom(methodArgs[i].GetType()))
                            {
                                methodArgs[i] = Convert.ChangeType(methodArgs[i], methodParameters[i].ParameterType);
                            }
                        }
                        catch (Exception ex)
                        {
                            return CreateErrorResponse($"Cannot convert parameter {i} to {methodParameters[i].ParameterType.Name}: {ex.Message}");
                        }
                    }
                }
                
                // Invoke the method
                McpLogger.LogInfo($"Invoking {typeName}.{methodName} with {methodArgs.Length} parameters");
                
                object result = method.Invoke(null, methodArgs);
                
                // Prepare response
                var response = new JObject
                {
                    ["success"] = true,
                    ["type"] = "text",
                    ["message"] = $"Successfully invoked {typeName}.{methodName}"
                };
                
                // Add return value if any
                if (method.ReturnType != typeof(void) && result != null)
                {
                    response["returnValue"] = SerializeReturnValue(result);
                    response["returnType"] = method.ReturnType.FullName;
                }
                
                return response;
            }
            catch (TargetInvocationException tie)
            {
                return CreateErrorResponse($"Method execution failed: {tie.InnerException?.Message ?? tie.Message}");
            }
            catch (Exception ex)
            {
                return CreateErrorResponse($"Unexpected error: {ex.Message}");
            }
        }
        
        private Type FindType(string typeName)
        {
            // First try to get type directly
            Type type = Type.GetType(typeName);
            if (type != null) return type;
            
            // Search in all loaded assemblies
            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                type = assembly.GetType(typeName);
                if (type != null) return type;
                
                // Try with assembly name prefix
                if (!typeName.Contains("."))
                {
                    foreach (var t in assembly.GetTypes())
                    {
                        if (t.Name == typeName)
                            return t;
                    }
                }
            }
            
            return null;
        }
        
        private (bool success, object value, Type type, string error) ConvertParameter(string typeName, JToken value)
        {
            try
            {
                switch (typeName.ToLower())
                {
                    // Primitive types
                    case "string":
                        return (true, value?.ToObject<string>(), typeof(string), null);
                    case "int":
                    case "int32":
                        return (true, value?.ToObject<int>() ?? 0, typeof(int), null);
                    case "float":
                    case "single":
                        return (true, value?.ToObject<float>() ?? 0f, typeof(float), null);
                    case "double":
                        return (true, value?.ToObject<double>() ?? 0d, typeof(double), null);
                    case "bool":
                    case "boolean":
                        return (true, value?.ToObject<bool>() ?? false, typeof(bool), null);
                    case "long":
                    case "int64":
                        return (true, value?.ToObject<long>() ?? 0L, typeof(long), null);
                    
                    // Unity types
                    case "vector2":
                        var v2 = value as JObject;
                        if (v2 != null)
                        {
                            var vec2 = new Vector2(
                                v2["x"]?.ToObject<float>() ?? 0,
                                v2["y"]?.ToObject<float>() ?? 0
                            );
                            return (true, vec2, typeof(Vector2), null);
                        }
                        break;
                        
                    case "vector3":
                        var v3 = value as JObject;
                        if (v3 != null)
                        {
                            var vec3 = new Vector3(
                                v3["x"]?.ToObject<float>() ?? 0,
                                v3["y"]?.ToObject<float>() ?? 0,
                                v3["z"]?.ToObject<float>() ?? 0
                            );
                            return (true, vec3, typeof(Vector3), null);
                        }
                        break;
                        
                    case "color":
                        var c = value as JObject;
                        if (c != null)
                        {
                            var color = new Color(
                                c["r"]?.ToObject<float>() ?? 0,
                                c["g"]?.ToObject<float>() ?? 0,
                                c["b"]?.ToObject<float>() ?? 0,
                                c["a"]?.ToObject<float>() ?? 1
                            );
                            return (true, color, typeof(Color), null);
                        }
                        break;
                    
                    // Arrays
                    case "string[]":
                        var strArray = value?.ToObject<string[]>();
                        return (true, strArray, typeof(string[]), null);
                        
                    case "int[]":
                        var intArray = value?.ToObject<int[]>();
                        return (true, intArray, typeof(int[]), null);
                        
                    case "float[]":
                        var floatArray = value?.ToObject<float[]>();
                        return (true, floatArray, typeof(float[]), null);
                    
                    // GameObject by name or path
                    case "gameobject":
                        var goName = value?.ToObject<string>();
                        if (!string.IsNullOrEmpty(goName))
                        {
                            GameObject go = GameObject.Find(goName);
                            if (go == null)
                            {
                                // Try to find in hierarchy by path
                                go = GameObject.Find("/" + goName);
                            }
                            return (true, go, typeof(GameObject), null);
                        }
                        break;
                    
                    default:
                        // Try to find the type and convert
                        Type customType = FindType(typeName);
                        if (customType != null)
                        {
                            if (customType.IsEnum)
                            {
                                var enumValue = Enum.Parse(customType, value?.ToObject<string>());
                                return (true, enumValue, customType, null);
                            }
                            else
                            {
                                var obj = value?.ToObject(customType);
                                return (true, obj, customType, null);
                            }
                        }
                        break;
                }
                
                return (false, null, null, $"Unsupported parameter type: {typeName}");
            }
            catch (Exception ex)
            {
                return (false, null, null, $"Error converting parameter: {ex.Message}");
            }
        }
        
        private JToken SerializeReturnValue(object value)
        {
            if (value == null) return null;
            
            Type type = value.GetType();
            
            // Handle primitive types
            if (type.IsPrimitive || type == typeof(string) || type == typeof(decimal))
            {
                return JToken.FromObject(value);
            }
            
            // Handle Unity types
            if (type == typeof(Vector2))
            {
                var v = (Vector2)value;
                return new JObject { ["x"] = v.x, ["y"] = v.y };
            }
            
            if (type == typeof(Vector3))
            {
                var v = (Vector3)value;
                return new JObject { ["x"] = v.x, ["y"] = v.y, ["z"] = v.z };
            }
            
            if (type == typeof(Color))
            {
                var c = (Color)value;
                return new JObject { ["r"] = c.r, ["g"] = c.g, ["b"] = c.b, ["a"] = c.a };
            }
            
            // Handle arrays and lists
            if (type.IsArray || type.GetInterface("IEnumerable") != null)
            {
                return JArray.FromObject(value);
            }
            
            // Handle GameObjects
            if (value is GameObject go)
            {
                return new JObject 
                { 
                    ["name"] = go.name,
                    ["instanceId"] = go.GetInstanceID(),
                    ["active"] = go.activeSelf
                };
            }
            
            // Default serialization
            try
            {
                return JToken.FromObject(value);
            }
            catch
            {
                // If serialization fails, return string representation
                return value.ToString();
            }
        }
        
        private JObject CreateErrorResponse(string message)
        {
            return McpUnitySocketHandler.CreateErrorResponse(message, "invocation_error");
        }
    }
}