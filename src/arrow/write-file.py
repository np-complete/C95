#!/usr/bin/env python

import pyarrow as pa
import os

fields =[
    ('uint8',  pa.uint8()),
    ('uint16', pa.uint16()),
    ('uint32',  pa.uint32()),
    ('uint64', pa.uint64()),
    ('int8',  pa.int8()),
    ('int16', pa.int16()),
    ('int32',  pa.int32()),
    ('int64', pa.int64()),
    ('float', pa.float32()),
    ('double', pa.float64()),
]
schema = pa.schema(fields)

uints = [1, 2, 4, 8]
ints = [1, -2, 4, -8]
floats = [1.1, -2.2, 4.4, -8.8]

columns = [
    pa.array(uints, type = pa.uint8()),
    pa.array(uints, type = pa.uint16()),
    pa.array(uints, type = pa.uint32()),
    pa.array(uints, type = pa.uint64()),
    pa.array(ints, type = pa.int8()),
    pa.array(ints, type = pa.int16()),
    pa.array(ints, type = pa.int32()),
    pa.array(ints, type = pa.int64()),
    pa.array(floats, type = pa.float32()),
    pa.array(floats, type = pa.float64()),
]

with pa.OSFile('/tmp/python.arrow', 'wb') as f:
    writer = pa.RecordBatchFileWriter(f, schema)
    for i in range(int(os.getenv('TIMES', 1))):
        record_batch = pa.RecordBatch.from_arrays(columns, schema)
        writer.write_batch(record_batch)

        sliced_columns = [column[1:] for column in columns]
        record_batch = pa.RecordBatch.from_arrays(sliced_columns, schema)
        writer.write_batch(record_batch)
    writer.close()
