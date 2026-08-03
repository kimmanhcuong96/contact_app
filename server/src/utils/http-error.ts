export class HttpError extends Error {
  constructor(public status: number, message: string, public code = 'request_error') {
    super(message);
  }
}

