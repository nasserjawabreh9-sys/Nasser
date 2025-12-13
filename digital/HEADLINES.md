# DIGITAL HEADLINES (Station Factory)
- Identity is file-based (IDENTITY.json)
- Chat Tree is file-based (spec/chat_tree.json)
- Environment Matrix is file-based (spec/env_matrix.json)
- Execution is file-based (run/*.sh)
- Backend wiring is file-based (patch markers in backend/main.py)
- Factory is real endpoints: /uul/factory/* + /uul/loop/*
- Loop 4 is a real runner: polls tasks -> executes -> reports results
