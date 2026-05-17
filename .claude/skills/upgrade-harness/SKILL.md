---
name: upgrade-harness
description: Extend the ouros sandbox with new external functions (bridge functions, security policy, tests)
user-invocable: true
allowed-tools: [Read, Edit, Write, Bash, Grep, Glob, AskUserQuestion]
---

Walk through adding a new external function to the ouros sandbox harness. External functions are the sandbox's only way to interact with the outside world — each one pauses Python execution, runs the real operation on the host, and returns the result.

Use when adding capabilities like "perplexity search to the sandbox", "Slack messages from sandbox", "database query function", or "extend sandbox with X".

The harness lives at `.claude/tools/ouros_harness.py` with extensive built-in functions: `exa_search`, `nia_search` variants, `llm_call`, `agent_call`, `read_file`, `write_file`, `glob_files`, `run_command`, `research_package`, `pipeline_start`, `pipeline_done`, plus security infrastructure for async web APIs, filesystem operations, and shell commands.

> **Fork-user caveat:** This skill edits `.claude/tools/ouros_harness.py` in place. If you cloned the harness from `second-brain-os`, the bundled file may be updated by upstream releases. Either upstream your additions via PR or keep your local edits separate to avoid merge conflicts on the next `extract-template.sh` extraction.

Start by understanding the request. Ask the user what function they want, what parameters it takes, whether it calls external APIs (async) or runs locally (sync), and what security constraints it needs (path restrictions, API keys, rate limits).

Read the current harness to understand existing patterns. Bridge functions are defined after imports, before SECURITY_POLICY. The SECURITY_POLICY dict defines allowed paths/commands. EXTERNAL_FUNCTIONS dict maps names to handlers.

Write the bridge function following established patterns. For async functions that call web APIs, create an async function plus sync wrapper:

```python
async def _call_new_function(param1, param2="default"):
    """Bridge to the real API."""
    script_dir = Path(__file__).parent
    sys.path.insert(0, str(script_dir))
    from my_api_module import api_call

    if not param1:
        return {"error": "param1 is required"}

    return await api_call(param1=param1, param2=param2)

def _call_new_function_sync(*args, **kwargs):
    """Sync wrapper -- ouros external functions must be sync."""
    return asyncio.run(_call_new_function(*args, **kwargs))
```

For sync functions that run locally:

```python
def _call_new_function(param1, param2="default"):
    """Description of what this does."""
    if not _check_path_allowed(param1, SECURITY_POLICY["new_allow"]):
        return {"error": f"new_function denied: '{param1}' is outside allowed directories"}

    try:
        result = some_operation(param1, param2)
        return result
    except Exception as e:
        return {"error": f"new_function failed: {e}"}
```

Bridge functions must return JSON-serializable dicts or strings, catch all exceptions returning `{"error": "..."}`, keep parameters simple (strings, ints, bools, lists), and provide sync wrappers for async functions since ouros calls sync only.

Add security policy if the function accesses filesystem, network, or shell. Add rules to SECURITY_POLICY dict then use `_check_path_allowed()` or write custom checks. Security principles: deny by default, allowlists over denylists, check before executing, fail closed on errors.

Register in EXTERNAL_FUNCTIONS dict where the key name becomes what sandbox code calls:

```python
EXTERNAL_FUNCTIONS = {
    # ... existing functions ...
    "new_function": _call_new_function_sync,  # or _call_new_function for sync
}
```

Test end-to-end with smoke tests (does it work?), security tests (blocks unauthorized access?), and error handling tests (fails gracefully?). Run from project directory:

```bash
echo 'result = new_function("test_arg"); print(result)' | python .claude/tools/ouros_harness.py
```

Add test cases to `test_ouros_harness.py` if it exists. Update the function table in `.claude/CLAUDE.md` with the new capability. Install any Python package dependencies into `/tmp/ouros/.venv/bin/pip install package-name` and document what was installed. Copy any separate scripts to the harness directory.

Present completion checklist: bridge function written, security policy added, registered in EXTERNAL_FUNCTIONS, smoke tested, security tested, CLAUDE.md updated, dependencies installed and documented.
