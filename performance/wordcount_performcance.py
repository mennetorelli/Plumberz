import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

data = pd.read_excel('data.xlsx', index_col=[0, 1])

data.plot(kind='bar')