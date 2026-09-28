F="/root/coze-studio/tool-proxy/server.py"
s=open(F,encoding="utf-8").read()
old='''                else:
                    # no visible content yet: if the model is only emitting tool calls
                    # or this SSE event ended, the stream is safe -> replay buffer only.
                    if tool_only or ended:
                        exhausted = True
                        return
            exhausted = True
'''
new='''                else:
                    # No visible content yet. If this event ended AND it carried tool
                    # calls, the (fully assembled) tool arguments are complete -> safe
                    # to replay buffer only. Do NOT bail on the first tool delta, since
                    # tool arguments stream across many chunks and an early return would
                    # truncate them and break the caller's tool-call parsing.
                    if ended:
                        exhausted = True
                        return
            exhausted = True
'''
assert old in s
s=s.replace(old,new,1)
# tool_only var now unused in that branch but harmless; keep to avoid unused-name issues
open(F,"w",encoding="utf-8").write(s)
print("patched")
