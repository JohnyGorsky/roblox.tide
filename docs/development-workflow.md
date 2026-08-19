# Development Workflow

## Status transitions

```text
IDEA
→ PLANNED
→ READY
→ IN_PROGRESS
→ IMPLEMENTED
→ VERIFIED
```

Alternative terminal states:
- DEFERRED
- REMOVED

## Definition of IMPLEMENTED

Code/content exists in the intended project path.

## Definition of VERIFIED

A human or controlled automation actually exercised the relevant behavior in Roblox Studio/playtest and recorded the result.

## AI rule

Claude must inspect Studio via MCP before making claims about implementation state.
