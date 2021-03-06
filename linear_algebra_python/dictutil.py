## Task 2
def dict2list(dct, keylist): return [ dct[i] for i in keylist ]

def list2dict(L, keylist): return { x:y for (x,y) in list(zip(keylist,L)) }

## Task 3
def listrange2dict(L):
    """
    Input: a list
    Output: a dictionary that, for i = 0, 1, 2, . . . , len(L), maps i to L[i]

    You can use list2dict or write this from scratch
    """
    return { x:L[x] for x in range (len(L)) }

