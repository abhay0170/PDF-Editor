/// Shared run-state shape for the Merge/Split/Rotate/Extract tool
/// controllers — [T] is whatever identifies the result (a document id for
/// single-output tools, a list of ids for Split).
sealed class ToolRunState<T> {
  const ToolRunState();
}

class ToolIdle<T> extends ToolRunState<T> {
  const ToolIdle();
}

class ToolProcessing<T> extends ToolRunState<T> {
  const ToolProcessing();
}

class ToolSuccess<T> extends ToolRunState<T> {
  const ToolSuccess(this.result);

  final T result;
}

class ToolError<T> extends ToolRunState<T> {
  const ToolError(this.message);

  final String message;
}
