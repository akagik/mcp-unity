using System;
using System.Threading.Tasks;
using UnityEngine;

namespace McpUnity.Tests
{
    public static class TestAsyncMethods
    {
        // Simple async method that returns Task
        public static async Task TestSimpleAsync()
        {
            Debug.Log("Starting async method");
            await Task.Delay(1000);
            Debug.Log("Async method completed");
        }
        
        // Async method that returns Task<string>
        public static async Task<string> TestAsyncWithReturn(string prefix)
        {
            Debug.Log($"Starting async method with prefix: {prefix}");
            await Task.Delay(500);
            return $"{prefix} - Completed at {DateTime.Now}";
        }
        
        // Async method that returns Task<int>
        public static async Task<int> CalculateAsync(int a, int b)
        {
            Debug.Log($"Starting async calculation: {a} + {b}");
            await Task.Delay(200);
            var result = a + b;
            Debug.Log($"Calculation result: {result}");
            return result;
        }
        
        // Synchronous method for comparison
        public static string TestSync(string message)
        {
            Debug.Log($"Synchronous method called: {message}");
            return $"Sync result: {message}";
        }
    }
}