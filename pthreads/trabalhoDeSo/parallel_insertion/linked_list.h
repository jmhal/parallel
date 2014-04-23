typedef struct Node {
   int val;
   struct Node *next;
} Node;

Node *create_list(int value);
int insert_node(Node *head, int value);
void print_list(Node *head);