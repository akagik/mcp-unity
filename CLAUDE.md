# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MCP Unity is a hybrid Unity Package + Node.js server that bridges Unity Editor with AI assistants using the Model Context Protocol (MCP). The project consists of:
- **Unity Package** (`com.gamelovers.mcp-unity`): C# code running in Unity Editor
- **Node.js MCP Server** (`Server~/`): TypeScript server implementing the MCP protocol

## Essential Commands

### Building the Node.js Server
```bash
cd Server~
npm install          # Install dependencies
npm run build        # Compile TypeScript to JavaScript
npm start           # Run the server
```

### Development Commands
```bash
cd Server~
npm run watch        # Auto-compile on TypeScript changes
npm run inspector    # Debug with MCP Inspector
```

### Important Notes
- The `build/` directory doesn't exist initially - run `npm run build` first
- Project path CANNOT contain spaces
- Default WebSocket port: 8090
- Unity 2022.3+ and Node.js 18+ required

## Architecture Overview

### Unity-side (C#)
- **Editor/UnityBridge/**: Core WebSocket server and MCP message handling
  - `McpUnityServer.cs`: Main server class managing WebSocket connections
  - `SocketHandler.cs`: Handles individual client connections
  - `McpUnityEditorWindow.cs`: Unity Editor UI window

- **Editor/Tools/**: MCP tool implementations (extend `McpToolBase`)
  - Each tool handles specific Unity operations (e.g., AddAssetToScene, UpdateGameObject)
  - Tools are auto-discovered and registered via reflection

- **Editor/Resources/**: MCP resource implementations (extend `McpResourceBase`)
  - Provide read-only access to Unity data (e.g., GetAssets, GetConsoleLog)

- **Editor/Services/**: Dependency-injected services
  - Use Unity's dependency injection pattern
  - Example: `TestRunnerService` for executing Unity tests

### Node.js-side (TypeScript)
- **Server~/src/unity/**: Unity-specific server implementation
  - `UnityMcpServer.ts`: Main MCP server class
  - Handles routing between MCP clients and Unity WebSocket

- **Server~/src/resources/** & **Server~/src/tools/**: Mirror Unity's structure
  - TypeScript interfaces matching C# implementations

### Communication Flow
1. AI Client → MCP Protocol → Node.js Server
2. Node.js Server → WebSocket → Unity Editor
3. Unity processes request → WebSocket → Node.js Server
4. Node.js Server → MCP Protocol → AI Client

## Key Development Guidelines

### When Modifying Unity Code
- Follow dependency injection patterns for services
- Use `Undo.RecordObject()` for undo support in tools
- Mark async operations with `IsAsync = true`
- Handle errors with `JObject` responses containing error details
- Use `McpLogger` for consistent logging
- Ensure thread safety (async ops are marshaled to main thread)

### When Modifying TypeScript Code
- Target: ES2022, Module: NodeNext
- Strict mode is enabled
- Build output goes to `Server~/build/`
- Follow existing error handling patterns with `McpError`

### Testing Unity Functionality
The project provides MCP tools for running Unity tests:
- Use `RunTestsTool` to execute EditMode/PlayMode tests
- Tests can be filtered by name
- Results include pass/fail status and logs

### Common Tasks
- **Add new MCP tool**: Create class in `Editor/Tools/` extending `McpToolBase`
- **Add new MCP resource**: Create class in `Editor/Resources/` extending `McpResourceBase`
- **Debug issues**: Use MCP Inspector (`npm run inspector`) and check Unity console logs
- **Update dependencies**: Modify `Server~/package.json` and run `npm install`

## Important Constraints
- Unity code runs on main thread only
- WebSocket communication is asynchronous
- Project paths cannot contain spaces
- All MCP operations have a 10-second timeout by default