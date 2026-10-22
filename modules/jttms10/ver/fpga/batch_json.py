#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Read batch JSON envelopes without retaining the complete case matrix.

Each batch is decoded by the standard JSON decoder. A complete initial scan
validates the envelope and counts batches; subsequent iterations reopen the
same file and retain only the current batch. Callers bind the file's hash.
"""
import json
from pathlib import Path


class _Reader:
    def __init__(self, stream, chunk_size, value_limit):
        self.stream = stream
        self.chunk_size = chunk_size
        self.value_limit = value_limit
        self.buffer = ''
        self.position = 0
        self.eof = False
        self.decoder = json.JSONDecoder()

    def more(self):
        self.buffer = self.buffer[self.position:]
        self.position = 0
        part = self.stream.read(self.chunk_size)
        self.buffer += part
        self.eof = not part
        if len(self.buffer) > self.value_limit:
            raise ValueError('batch JSON value exceeds the configured memory bound')

    def peek(self):
        while True:
            while self.position < len(self.buffer) and self.buffer[self.position].isspace():
                self.position += 1
            if self.position < len(self.buffer) or self.eof:
                return self.buffer[self.position:self.position + 1]
            self.more()

    def take(self, token):
        if self.peek() != token:
            raise ValueError(f'batch JSON expected {token!r}')
        self.position += 1

    def value(self):
        self.peek()
        while True:
            try:
                value, end = self.decoder.raw_decode(self.buffer, self.position)
            except json.JSONDecodeError:
                if self.eof:
                    raise
                self.more()
                continue
            # A number can end provisionally at a chunk boundary, including
            # before an incomplete exponent. Wait for a real delimiter/EOF.
            if not self.eof and (end == len(self.buffer) or
                    self.buffer[end] not in ',]} \t\r\n:'):
                self.more()
                continue
            self.position = end
            return value


class BatchFile:
    """Reiterable batch sequence with a fully validated, bounded envelope."""
    def __init__(self, path, *, chunk_size=65536, value_limit=16 * 1024 * 1024):
        if chunk_size < 1 or value_limit < chunk_size:
            raise ValueError('invalid batch JSON read limits')
        self.path = Path(path)
        self.chunk_size = chunk_size
        self.value_limit = value_limit
        self.metadata = {}
        self.count = 0
        for _ in self._read():
            self.count += 1

    def _read(self):
        metadata = {}
        seen = set()
        with self.path.open(encoding='utf-8') as stream:
            reader = _Reader(stream, self.chunk_size, self.value_limit)
            reader.take('{')
            if reader.peek() == '}':
                raise ValueError('batch JSON lacks batches')
            while True:
                key = reader.value()
                if not isinstance(key, str) or key in seen:
                    raise ValueError('invalid or duplicate batch JSON envelope key')
                seen.add(key)
                reader.take(':')
                if key == 'batches':
                    reader.take('[')
                    if reader.peek() != ']':
                        while True:
                            batch = reader.value()
                            if not isinstance(batch, dict):
                                raise ValueError('batch JSON array element must be an object')
                            yield batch
                            if reader.peek() == ']':
                                break
                            reader.take(',')
                    reader.take(']')
                else:
                    metadata[key] = reader.value()
                if reader.peek() == '}':
                    break
                reader.take(',')
            reader.take('}')
            if reader.peek():
                raise ValueError('trailing data after batch JSON envelope')
            if 'batches' not in seen:
                raise ValueError('batch JSON lacks batches')
        self.metadata = metadata

    def __len__(self):
        return self.count

    def __iter__(self):
        count = 0
        for batch in self._read():
            count += 1
            yield batch
        if count != self.count:
            raise ValueError('batch JSON count changed since inspection')

    def __getitem__(self, index):
        if not isinstance(index, int):
            raise TypeError('batch index must be an integer')
        if index < 0:
            index += self.count
        if not 0 <= index < self.count:
            raise IndexError('batch index outside the document')
        for current, batch in enumerate(self):
            if current == index:
                return batch
        raise ValueError('batch JSON truncated since inspection')


def load_document(path):
    batches = BatchFile(path)
    return dict(batches.metadata, batches=batches)
