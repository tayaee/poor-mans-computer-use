MSG=$(git diff @{u} --staged | opencode run -m opencode-go/muse-spark-1.3-contributor "Output ONLY a 1-line commit message. No tools, no markdown, no quotes." 2>/dev/null | grep -v -e '^$' -e '^>' | tail -n 1)
echo ${MSG:-No description commit}
