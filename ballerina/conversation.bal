// Copyright (c) 2026, Hasitha Erandika (http://github.com/HasithaErandika).
// Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: Apache-2.0

# A stateful conversation manager that maintains full chat history across turns.
#
# Handles message history automatically so callers only need to provide the next
# user message and receive the assistant reply. Thread-safe via lock statements.
#
# ### Basic usage
# ```ballerina
# huggingface:Conversation conv = new (hfClient, "katanemo/Arch-Router-1.5B:hf-inference");
# string reply1 = check conv.chat("What is Ballerina?");
# string reply2 = check conv.chat("Who created it?");
# io:println("Turns: ", conv.turnCount());
# conv.reset();
# ```
#
# ### With system prompt
# ```ballerina
# huggingface:Conversation conv = new (
#     hfClient,
#     "katanemo/Arch-Router-1.5B:hf-inference",
#     systemPrompt = "You are a helpful Ballerina programming assistant.",
#     maxTokens = 150
# );
# string reply = check conv.chat("How do I write a REST service?");
# ```
public isolated class Conversation {
    private final Client hfClient;
    private final string model;
    private final int maxTokens;
    private final string systemPromptText;
    private ChatMessage[] history = [];

    # Creates a new Conversation with the given client and model.
    #
    # + hfClient - A configured `Client` instance
    # + model - The chat model ID to use for generation
    # + systemPrompt - Optional system prompt to set assistant behaviour
    # + maxTokens - Maximum tokens per response (default: 200)
    public isolated function init(
            Client hfClient,
            string model,
            string systemPrompt = "",
            int maxTokens = 200) {
        self.hfClient = hfClient;
        self.model = model;
        self.maxTokens = maxTokens;
        self.systemPromptText = systemPrompt;
        if systemPrompt.length() > 0 {
            lock {
                self.history.push({role: "system", content: systemPrompt});
            }
        }
    }

    # Send a user message and receive the assistant reply.
    #
    # The conversation history is updated automatically after each call.
    #
    # + userMessage - The user message to send
    # + return - The assistant reply as a plain string, or an error
    public isolated function chat(string userMessage) returns string|error {
        ChatMessage[] currentHistory;
        lock {
            self.history.push({role: "user", content: userMessage});
            currentHistory = self.history.clone();
        }

        ChatCompletionResponse resp = check self.hfClient->/v1/chat/completions.post({
            model: self.model,
            messages: currentHistory,
            maxTokens: self.maxTokens
        });

        string reply = "";
        ChatCompletionChoice[]? choices = resp?.choices;
        if choices is ChatCompletionChoice[] && choices.length() > 0 {
            ChatMessage? msg = choices[0].message;
            if msg is ChatMessage {
                reply = msg.content;
            }
        }

        lock {
            self.history.push({role: "assistant", content: reply});
        }

        return reply;
    }

    # Get the full conversation history including all turns.
    #
    # + return - Ordered array of all messages in the conversation
    public isolated function getHistory() returns ChatMessage[] {
        lock {
            return self.history.clone();
        }
    }

    # Get a snapshot of the current conversation state.
    #
    # + return - A ConversationSnapshot record with history, model, and turn count
    public isolated function snapshot() returns ConversationSnapshot {
        ChatMessage[] currentHistory;
        string currentModel = self.model;
        int currentCount = self.countTurns();
        lock {
            currentHistory = self.history.clone();
        }
        return {
            history: currentHistory,
            model: currentModel,
            turnCount: currentCount
        };
    }

    # Reset the conversation history.
    #
    # If a system prompt was provided at initialization it is preserved.
    # All user and assistant messages are cleared.
    public isolated function reset() {
        lock {
            ChatMessage[] fresh = [];
            if self.systemPromptText.length() > 0 {
                fresh.push({role: "system", content: self.systemPromptText});
            }
            self.history = fresh;
        }
    }

    # Get the number of completed user/assistant exchange pairs.
    #
    # + return - Number of turns (each user message counts as one turn)
    public isolated function turnCount() returns int {
        return self.countTurns();
    }

    # Internal helper — count user turns.
    #
    # + return - Number of user messages
    private isolated function countTurns() returns int {
        int count = 0;
        ChatMessage[] currentHistory;
        lock {
            currentHistory = self.history.clone();
        }
        foreach ChatMessage msg in currentHistory {
            if msg.role == "user" {
                count += 1;
            }
        }
        return count;
    }
}
