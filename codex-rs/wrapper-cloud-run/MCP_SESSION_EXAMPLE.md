# MCP Session Initialization for Cloud Run Servers

## Overview

This document describes how to configure Codex to connect to MCP servers deployed on Cloud Run (or similar platforms) that require session initialization via a separate endpoint.

## Problem Statement

Some MCP servers follow the SSE (Server-Sent Events) pattern where:
1. A POST request must be made to a `/sessions` endpoint to obtain a `session_id`
2. The `session_id` is then used to construct the messages URL
3. Subsequent MCP protocol messages are sent to `/messages/{session_id}`

## Solution

The Codex RMCP client now supports optional session initialization through the `session_url` configuration parameter.

## Configuration Example

### Basic HTTP MCP Server (no session)

```toml
[mcp_servers.simple]
url = "https://example.com/mcp/messages/"
startup_timeout_sec = 30
tool_timeout_sec = 120
```

### Cloud Run MCP Server with Session Initialization

```toml
[mcp_servers.pipedrive]
session_url = "https://mcp-pipedrive-467992722695.us-central1.run.app/sessions"
url = "https://mcp-pipedrive-467992722695.us-central1.run.app/messages/"
startup_timeout_sec = 30
tool_timeout_sec = 120
```

### With Authentication

```toml
[mcp_servers.authenticated]
session_url = "https://api.example.com/sessions"
url = "https://api.example.com/messages/"
bearer_token = "your-secret-token-here"
startup_timeout_sec = 30
tool_timeout_sec = 120
```

## How It Works

When `session_url` is provided:

1. **Session Initialization**: The client makes a POST request to the `session_url`:
   ```
   POST /sessions
   Authorization: Bearer {bearer_token}  (if provided)
   ```

2. **Session Response**: The server responds with a JSON object containing the session ID:
   ```json
   {
     "session_id": "abc123xyz"
   }
   ```

3. **URL Construction**: The client appends the `session_id` to the messages URL:
   ```
   Original URL:  https://example.com/messages/
   Final URL:     https://example.com/messages/abc123xyz
   ```

4. **MCP Protocol**: The client then uses the final URL for all MCP protocol messages (initialize, list_tools, call_tool, etc.)

## Implementation Details

### Code Changes

1. **Config Types** ([config_types.rs](codex-rs/wrapper-cloud-run/core/src/config_types.rs))
   - Added `session_url: Option<String>` to `McpServerTransportConfig::StreamableHttp`

2. **RMCP Client** ([rmcp_client.rs](codex-rs/wrapper-cloud-run/rmcp-client/src/rmcp_client.rs))
   - Added `initialize_server_session()` helper function
   - Updated `new_streamable_http_client()` to accept `session_url` parameter
   - Performs session initialization before creating the transport

3. **Connection Manager** ([mcp_connection_manager.rs](codex-rs/wrapper-cloud-run/core/src/mcp_connection_manager.rs))
   - Updated `new_streamable_http_client()` to pass `session_url` from config

### Session Response Format

The session endpoint must return a JSON response with the following structure:

```json
{
  "session_id": "string"
}
```

Example valid responses:
```json
{"session_id": "sess_abc123"}
{"session_id": "1234567890"}
{"session_id": "user-session-xyz"}
```

## Error Handling

The client will return errors in the following cases:

1. **Session endpoint unreachable**: Network error when POSTing to `session_url`
2. **Non-2xx status code**: Server returned an error status (e.g., 401, 500)
3. **Invalid JSON response**: Response body is not valid JSON
4. **Missing session_id field**: JSON response doesn't contain `session_id`

## Testing

You can test your configuration with:

```bash
# List MCP servers
codex mcp list

# Test tool listing from the server
codex exec "list all tools from pipedrive server"
```

## Migration Guide

If you're currently using a simple URL-based MCP server that now requires session initialization:

**Before:**
```toml
[mcp_servers.myserver]
url = "https://myserver.example.com/mcp"
```

**After:**
```toml
[mcp_servers.myserver]
session_url = "https://myserver.example.com/sessions"
url = "https://myserver.example.com/messages/"
# Note: url should typically end with / for proper session_id appending
```

## Backwards Compatibility

This change is fully backwards compatible:
- Servers without `session_url` work exactly as before
- The `session_url` field is optional
- Existing configurations continue to work without modification

## Future Enhancements

Potential improvements for future versions:
- Session caching and reuse across multiple connections
- Session refresh/renewal logic
- Custom session ID format handling (query params, headers, etc.)
- Session keepalive/heartbeat support
