#!/usr/bin/env python

import os
import pyarrow as pa

times = int(os.getenv('TIMES', 1))

for time in range(times):

    reader = pa.open_file('/tmp/python.arrow')
    schema = reader.schema

    for i in range(reader.num_record_batches):
        record_batch = reader.get_batch(i)
        if times > 1:
            break
        print('=' * 48)
        print(f'record-batch[{i}]:')
        for j, column in enumerate(schema):
            values = record_batch.column(j).to_numpy()
            print(f'  {column.name}: {record_batch.column(j).to_numpy()}')
