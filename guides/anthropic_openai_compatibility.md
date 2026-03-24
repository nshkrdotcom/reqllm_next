# Anthropic OpenAI Compatibility Evaluation

Status: Working Guide

## Purpose

Anthropic exposes an OpenAI SDK compatibility layer. This guide records how ReqLlmNext should treat that surface.

Official source:

1. [Anthropic OpenAI SDK compatibility](https://platform.claude.com/docs/en/api/openai-sdk)

## Conclusion

ReqLlmNext should keep the native Anthropic Messages lane as the primary integration surface.

The compatibility layer is useful for smoke-testing or migration experiments, but it is not a good architectural home for the package’s Anthropic support story.

## Why The Native Lane Wins

The native Anthropic surface exposes capabilities that are either invisible or awkward through the compatibility layer:

1. prompt caching
2. 1M-context beta controls
3. `output_config.format` structured outputs
4. citations and document blocks
5. `file_id` document references and Files API integration
6. token counting
7. message batches
8. context-management controls
9. provider-native tools such as web search, code execution, MCP connectors, and computer use
10. Anthropic-specific stop reasons and richer content-block semantics

ReqLlmNext is trying to support the widest provider surface area possible while still keeping a deterministic execution-plan architecture. The compatibility layer hides too many Anthropic-specific execution details to be the primary path.

## Recommended Role

The compatibility layer should be treated as:

1. a migration aid for users already invested in OpenAI SDK semantics
2. a secondary evaluation target for documentation and drift analysis
3. not a replacement for native Anthropic planning, protocol, wire, or utility modules

## Package Impact

ReqLlmNext should therefore:

1. keep Anthropic on the native `:anthropic_messages` execution family
2. keep Anthropic-specific utility endpoints under `ReqLlmNext.Anthropic.*`
3. avoid routing native Anthropic model support through OpenAI-compatible wire assumptions
4. evaluate compatibility behavior separately when it is useful, without letting it drive the core Anthropic architecture
