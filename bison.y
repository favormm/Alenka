/*
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */


%{

#include "lex.yy.c"
#include "cm.h"

    void clean_queues();
    void order_inplace(CudaSet* a, stack<string> exe_type);
    void yyerror(char *s, ...);
    void emit(char *s, ...);
    void emit_mul();
    void emit_add();
    void emit_minus();
    void emit_distinct();
    void emit_div();
    void emit_and();
    void emit_eq();
    void emit_or();
    void emit_cmp(int val);
    void emit_var(char *s, int c, char *f);
    void emit_var_asc(char *s);
    void emit_var_desc(char *s);
    void emit_name(char *name);
    void emit_count();
    void emit_sum();
    void emit_average();
    void emit_min();
    void emit_max();
    void emit_string(char *str);
    void emit_number(int_type val);
    void emit_float(float_type val);
    void emit_decimal(float_type val);
    void emit_sel_name(char* name);
    void emit_limit(int val);
    void emit_union(char *s, char *f1, char *f2);
    void emit_varchar(char *s, int c, char *f, int d);
    void emit_load(char *s, char *f, int d, char* sep);
    void emit_load_binary(char *s, char *f, int d);
    void emit_store(char *s, char *f, char* sep);
    void emit_store_binary(char *s, char *f, char* sep);
    void emit_store_binary(char *s, char *f);
    void emit_filter(char *s, char *f, int e);
    void emit_order(char *s, char *f, int e, int ll = 0);
    void emit_group(char *s, char *f, int e);
    void emit_select(char *s, char *f, int ll);
    void emit_join(char *s, char *j1, int grp);
    void emit_join_tab(char *s, char tp);
    void emit_distinct();
	void emit_join();
	void emit_sort(char* s);

%}

%union {
    int intval;
    float floatval;
    char *strval;
    int subtok;
}

%token <strval> FILENAME
%token <strval> NAME
%token <strval> STRING
%token <intval> INTNUM
%token <intval> DECIMAL1
%token <intval> BOOL1
%token <floatval> APPROXNUM
/* user @abc names */
%token <strval> USERVAR
/* operators and precedence levels */
%right ASSIGN
%right EQUAL
%left OR
%left XOR
%left AND
%left DISTINCT
%nonassoc IN IS LIKE REGEXP
%left NOT '!'
%left BETWEEN
%left <subtok> COMPARISON /* = <> < > <= >= <=> */
%left '|'
%left '&'
%left <subtok> SHIFT /* << >> */
%left '+' '-'
%left '*' '/' '%' MOD
%left '^'
%nonassoc UMINUS

%token OR
%token LOAD
%token STREAM
%token FILTER
%token BY
%token JOIN
%token STORE
%token INTO
%token GROUP
%token FROM
%token SELECT
%token AS
%token ORDER
%token ASC
%token DESC
%token COUNT
%token USING
%token SUM
%token AVG
%token MIN
%token MAX
%token LIMIT
%token ON
%token BINARY
%token DISTINCT
%token LEFT
%token RIGHT
%token OUTER
%token AND
%token SORT
%token SEGMENTS

%type <intval> load_list  opt_where opt_limit sort_def
%type <intval> val_list opt_val_list expr_list opt_group_list join_list
%start stmt_list
%%


/* Grammar rules and actions follow. */

stmt_list:
stmt ';'
| stmt_list stmt ';'
;

stmt:
select_stmt { emit("STMT"); }
;
select_stmt:
NAME ASSIGN SELECT expr_list FROM NAME opt_group_list
{ emit_select($1, $6, $7); } ;
| NAME ASSIGN LOAD FILENAME USING '(' FILENAME ')' AS '(' load_list ')'
{  emit_load($1, $4, $11, $7); } ;
| NAME ASSIGN LOAD FILENAME BINARY AS '(' load_list ')'
{  emit_load_binary($1, $4, $8); } ;
| NAME ASSIGN FILTER NAME opt_where
{  emit_filter($1, $4, $5);}
| NAME ASSIGN ORDER NAME BY opt_val_list
{  emit_order($1, $4, $6);}
| NAME ASSIGN SELECT expr_list FROM NAME join_list opt_group_list
{ emit_join($1,$6,$7); }
| STORE NAME INTO FILENAME USING '(' FILENAME ')' opt_limit
{ emit_store($2,$4,$7); }
| STORE NAME INTO FILENAME opt_limit BINARY sort_def
{ emit_store_binary($2,$4); }
;

expr:
NAME { emit_name($1); }
| NAME '.' NAME { emit("FIELDNAME %s.%s", $1, $3); }
| USERVAR { emit("USERVAR %s", $1); }
| STRING { emit_string($1); }
| INTNUM { emit_number($1); }
| APPROXNUM { emit_float($1); }
| DECIMAL1 { emit_decimal($1); }
| BOOL1 { emit("BOOL %d", $1); }
| NAME '{' INTNUM '}' ':' NAME '(' INTNUM ')' { emit_varchar($1, $3, $6, $8);}
| NAME '{' INTNUM '}' ':' NAME  { emit_var($1, $3, $6);}
| NAME ASC { emit_var_asc($1);}
| NAME DESC { emit_var_desc($1);}
| COUNT '(' expr ')' { emit_count(); }
| SUM '(' expr ')' { emit_sum(); }
| AVG '(' expr ')' { emit_average(); }
| MIN '(' expr ')' { emit_min(); }
| MAX '(' expr ')' { emit_max(); }
| DISTINCT expr { emit_distinct(); }
| JOIN { emit_join(); }
;

expr:
expr '+' expr { emit_add(); }
| expr '-' expr { emit_minus(); }
| expr '*' expr { emit_mul(); }
| expr '/' expr { emit_div(); }
| expr '%' expr { emit("MOD"); }
| expr MOD expr { emit("MOD"); }
/*| '-' expr %prec UMINUS { emit("NEG"); }*/
| expr AND expr { emit_and(); }
| expr EQUAL expr { emit_eq(); }
| expr OR expr { emit_or(); }
| expr XOR expr { emit("XOR"); }
| expr SHIFT expr { emit("SHIFT %s", $2==1?"left":"right"); }
| NOT expr { emit("NOT"); }
| '!' expr { emit("NOT"); }
| expr COMPARISON expr { emit_cmp($2); }
/* recursive selects and comparisons thereto */
| expr COMPARISON '(' select_stmt ')' { emit("CMPSELECT %d", $2); }
| '(' expr ')' {emit("EXPR");}
;

expr:
expr IS BOOL1 { emit("ISBOOL %d", $3); }
| expr IS NOT BOOL1 { emit("ISBOOL %d", $4); emit("NOT"); }
;

opt_group_list: { /* nil */
    $$ = 0;
}
| GROUP BY val_list { $$ = $3}


expr_list:
expr AS NAME { $$ = 1; emit_sel_name($3);}
| expr_list ',' expr AS NAME { $$ = $1 + 1; emit_sel_name($5);}
;

load_list:
expr { $$ = 1; }
| load_list ',' expr {$$ = $1 + 1; }
;

val_list:
expr { $$ = 1; }
| expr ',' val_list { $$ = 1 + $3; }
;

opt_val_list: { /* nil */
    $$ = 0
}  | val_list;

opt_where:
BY expr { emit("FILTER BY"); };

join_list:
JOIN NAME ON expr{ $$ = 1; emit_join_tab($2, 'I');}
| LEFT JOIN NAME ON expr{ $$ = 1; emit_join_tab($3, 'L');}
| RIGHT JOIN NAME ON expr { $$ = 1; emit_join_tab($3, 'R');}
| OUTER JOIN NAME ON expr { $$ = 1; emit_join_tab($3, 'O');}
| JOIN NAME ON expr join_list{ $$ = 1; emit_join_tab($2, 'I'); };
| LEFT JOIN NAME ON expr join_list { $$ = 1; emit_join_tab($3, 'L'); };
| RIGHT JOIN NAME ON expr join_list { $$ = 1; emit_join_tab($3, 'R'); };
| OUTER JOIN NAME ON expr join_list { $$ = 1; emit_join_tab($3, 'O'); };

opt_limit: { /* nil */
    $$ = 0
}
     | LIMIT INTNUM { emit_limit($2); };

sort_def: { /* nil */
    $$ = 0
}
     |SORT SEGMENTS BY NAME { emit_sort($4); };

%%

#include "filter.h"
#include "select.h"
#include "merge.h"
#include "zone_map.h"
#include "atof.h"
#include "cudpp_src_2.0/include/cudpp_hash.h"
#include "moderngpu-master/include/kernels/join.cuh"
#include "moderngpu-master/include/util/mgpucontext.h"
#include "sstream"
#include "sorts.cu"

string to_string1(long long int i) {
	stringstream res;
	res << i;
	return res.str();
}

using namespace mgpu;

size_t int_size = sizeof(int_type);
size_t float_size = sizeof(float_type);

FILE *file_pointer;
queue<string> namevars;
queue<string> typevars;
queue<int> sizevars;
queue<int> cols;

queue<unsigned int> j_col_count;
unsigned int sel_count = 0;
unsigned int join_cnt = 0;
unsigned int distinct_cnt = 0;
unsigned int join_col_cnt = 0;
unsigned int join_tab_cnt = 0;
unsigned int tab_cnt = 0;
queue<string> op_join;
queue<char> join_type;


unsigned int statement_count = 0;
map<string,unsigned int> stat;
map<unsigned int, unsigned int> join_and_cnt;
bool scan_state = 0;
string separator, f_file;
unsigned int int_col_count;
CUDPPHandle theCudpp;
ContextPtr context;

void emit_multijoin(string s, string j1, string j2, unsigned int tab, char* res_name);

using namespace thrust::placeholders;


void emit_name(char *name)
{
    op_type.push("NAME");
    op_value.push(name);
}

void emit_limit(int val)
{
    op_nums.push(val);
}


void emit_string(char *str)
{   // remove the float_type quotes
    string sss(str,1, strlen(str)-2);
    op_type.push("STRING");
    op_value.push(sss);
}


void emit_number(int_type val)
{
    op_type.push("NUMBER");
    op_nums.push(val);
}

void emit_float(float_type val)
{
    op_type.push("FLOAT");
    op_nums_f.push(val);
}

void emit_decimal(float_type val)
{
    op_type.push("DECIMAL");
    op_nums_f.push(val);
}



void emit_mul()
{
    op_type.push("MUL");
}

void emit_add()
{
    op_type.push("ADD");
}

void emit_div()
{
    op_type.push("DIV");
}

unsigned int misses = 0;

void emit_and()
{
    op_type.push("AND");
    join_col_cnt++;
	//cout << "AND "  << endl;	
}

void emit_eq()
{    
    op_type.push("JOIN");
	if(misses == 0) {
		join_and_cnt[tab_cnt] = join_col_cnt;	
		//cout << "ASSIGN " << tab_cnt << " " << join_and_cnt[tab_cnt] << endl;
		misses = join_col_cnt;
		join_col_cnt = 0;		
		tab_cnt++;
	}
	else {
		misses--;
	}
	//cout << "eq " << endl;
}

void emit_distinct()
{
    op_type.push("DISTINCT");
    distinct_cnt++;
}

void emit_join()
{
   cout << "emit join " << endl;
}


void emit_or()
{
    op_type.push("OR");
}


void emit_minus()
{
    op_type.push("MINUS");
}

void emit_cmp(int val)
{
    op_type.push("CMP");
    op_nums.push(val);
}

void emit(char *s, ...)
{


}

void emit_var(char *s, int c, char *f)
{
    namevars.push(s);
    typevars.push(f);
    sizevars.push(0);
    cols.push(c);
}

void emit_var_asc(char *s)
{
    op_type.push(s);
    op_value.push("ASC");
}

void emit_var_desc(char *s)
{
    op_type.push(s);
    op_value.push("DESC");
}

void emit_sort(char *s)
{
	op_sort.push(s); 
}



void emit_varchar(char *s, int c, char *f, int d)
{
    namevars.push(s);
    typevars.push(f);
    sizevars.push(d);
    cols.push(c);
}

void emit_sel_name(char *s)
{
    op_type.push("emit sel_name");
    op_value.push(s);
    sel_count++;
}

void emit_count()
{
    op_type.push("COUNT");
}

void emit_sum()
{
    op_type.push("SUM");
}


void emit_average()
{
    op_type.push("AVG");
}

void emit_min()
{
    op_type.push("MIN");
}

void emit_max()
{
    op_type.push("MAX");
}

void emit_join_tab(char *s, char tp)
{
    op_join.push(s);
	join_tab_cnt++;
    join_type.push(tp);
	//cout << "join tab " << join_tab_cnt << endl;
};


void order_inplace(CudaSet* a, stack<string> exe_type, set<string> field_names)
{
    //std::clock_t start1 = std::clock();
    unsigned int sz = a->mRecCount;
    thrust::device_ptr<unsigned int> permutation = thrust::device_malloc<unsigned int>(sz);
    thrust::sequence(permutation, permutation+sz,0,1);

    unsigned int* raw_ptr = thrust::raw_pointer_cast(permutation);
    void* temp;
    // find the largest mRecSize of all data sources exe_type.top()
    unsigned int maxSize = 0;
    for (set<string>::iterator it=field_names.begin(); it!=field_names.end(); ++it) {
        CudaSet *t = varNames[setMap[*it]];
        if(t->mRecCount > maxSize)
            maxSize = t->mRecCount;
    };


    unsigned int max_c = max_char(a, field_names);
	//cout << "max_c " << max_c << " " << maxSize << " " << getFreeMem() << endl;

    if(max_c > float_size)
        CUDA_SAFE_CALL(cudaMalloc((void **) &temp, maxSize*max_c));
    else
        CUDA_SAFE_CALL(cudaMalloc((void **) &temp, maxSize*float_size));

    unsigned int str_count = 0;
	
	
    for(int i=0; !exe_type.empty(); ++i, exe_type.pop()) {
        int colInd = (a->columnNames).find(exe_type.top())->second;
        if (a->type[colInd] == 0)
            update_permutation(a->d_columns_int[a->type_index[colInd]], raw_ptr, sz, "ASC", (int_type*)temp);
        else if (a->type[colInd] == 1)
            update_permutation(a->d_columns_float[a->type_index[colInd]], raw_ptr, sz,"ASC", (float_type*)temp);
        else {
            // use int col int_col_count
	        update_permutation(a->d_columns_int[int_col_count+str_count], raw_ptr, sz, "ASC", (int_type*)temp);
	        str_count++;
        };
    };
	
    str_count = 0;

    for (set<string>::iterator it=field_names.begin(); it!=field_names.end(); ++it) {
        int i = a->columnNames[*it];
        if (a->type[i] == 0) {
            apply_permutation(a->d_columns_int[a->type_index[i]], raw_ptr, sz, (int_type*)temp);			
		}	
        else if (a->type[i] == 1)
            apply_permutation(a->d_columns_float[a->type_index[i]], raw_ptr, sz, (float_type*)temp);
        else {
            apply_permutation_char(a->d_columns_char[a->type_index[i]], raw_ptr, sz, (char*)temp, a->char_size[a->type_index[i]]);			
            apply_permutation(a->d_columns_int[int_col_count + str_count], raw_ptr, sz, (int_type*)temp);
            str_count++;
        };
    };
	
    cudaFree(temp);
    thrust::device_free(permutation);

}

bool check_star_join(string j1)
{
    queue<string> op_vals(op_value);
	queue<string> op_j(op_join);
	CudaSet* fact_table;
	
    for(unsigned int i=0; i < sel_count; i++) {        
        op_vals.pop();
        op_vals.pop();
    };
	
    if(join_tab_cnt > 1) {
	    fact_table = varNames[j1];
		
		while(op_vals.size()) {
			if (fact_table->columnNames.find(op_vals.front()) != fact_table->columnNames.end()) {
				op_vals.pop();
				op_vals.pop();
			}
            else {
				return 0;
			};	
		};
		return 1;
		
	}
	else
		return 0;


}

std::ostream &operator<<(std::ostream &os, const uint2 &x)
{
  os << x.x << ", " << x.y;
  return os;
}

void star_join(char *s, string j1)
{
   //need to copy to gpu all dimension keys, sort the dimension tables and
   //build an array of hash tables for the dimension tables
    CUDPPResult result;
	map<string,bool> already_copied;
   
    //cout << j1 << endl;
	CudaSet* left = varNames.find(j1)->second;
	
    queue<string> op_sel;
    queue<string> op_sel_as;
    for(int i=0; i < sel_count; i++) {
        op_sel.push(op_value.front());
        op_value.pop();
        op_sel_as.push(op_value.front());
        op_value.pop();
    };	
	queue<string> op_sel_s(op_sel);
	queue<string> op_sel_s_as(op_sel_as);
	queue<string> op_g(op_value);
	
	CudaSet* c = new CudaSet(op_sel_s, op_sel_s_as);

	
    CUDPPHandle* hash_table_handle = new CUDPPHandle[join_tab_cnt];
    CUDPPHashTableConfig config;
    config.type = CUDPP_MULTIVALUE_HASH_TABLE;    
    config.space_usage = 1.1f;  
    bool str_join = 0;	
	string f1, f2;
	unsigned int colInd1, tt = 0;
	bool v64bit = 0;
	unsigned int colInd2;
	map<string, unsigned int> tab_map;
	map<string, string> var_map;
	
	for(unsigned int i = 0; i < join_tab_cnt; i++) {

	    f1 = op_g.front();
		op_g.pop();
		f2 = op_g.front();
		op_g.pop();
	
        queue<string> op_jj(op_join);	
		for(unsigned int z = 0; z < (join_tab_cnt-1) - i; z++)
		    op_jj.pop();

		cout << "PROCESSING " << f2 <<   endl;
		
        unsigned int rcount;
        curr_segment = 10000000;
        queue<string> op_vd(op_g);
        queue<string> op_alt(op_sel);
        unsigned int jc = join_col_cnt;
        while(jc) {
            jc--;
            op_vd.pop();
            op_alt.push(op_vd.front());
            op_vd.pop();
        };
		
		//cout << "right is " << op_jj.front() << endl;
		tab_map[op_jj.front()] = i;
		var_map[op_jj.front()] = f1;

		CudaSet* right = varNames.find(op_jj.front())->second;
		colInd2 = right->columnNames[f2];
		
        unsigned int cnt_r = load_queue(op_alt, right, str_join, f2, rcount); // put all used columns into GPU
		
		bool sorted = thrust::is_sorted(right->d_columns_int[right->type_index[colInd2]].begin(), right->d_columns_int[right->type_index[colInd2]].begin() + cnt_r);


		if(!sorted) {

			queue<string> ss(op_sel);
			thrust::device_vector<unsigned int> v(cnt_r);
			thrust::sequence(v.begin(),v.end(),0,1);

			unsigned int max_c	= max_char(right);
			unsigned int mm;
			if(max_c > 8)
				mm = (max_c/8) + 1;
			else
				mm = 1;

			thrust::device_ptr<int_type> d_tmp = thrust::device_malloc<int_type>(cnt_r*mm);
			thrust::sort_by_key(right->d_columns_int[right->type_index[colInd2]].begin(), right->d_columns_int[right->type_index[colInd2]].begin() + cnt_r, v.begin());

			unsigned int i;
			while(!ss.empty()) {
				if (right->columnNames.find(ss.front()) != right->columnNames.end()) {
					i = right->columnNames[ss.front()];

					if(i != colInd2) {
						if(right->type[i] == 0) {
							thrust::gather(v.begin(), v.end(), right->d_columns_int[right->type_index[i]].begin(), d_tmp);
							thrust::copy(d_tmp, d_tmp + cnt_r, right->d_columns_int[right->type_index[i]].begin());
						}
						else if(right->type[i] == 1) {
							thrust::gather(v.begin(), v.end(), right->d_columns_float[right->type_index[i]].begin(), d_tmp);
							thrust::copy(d_tmp, d_tmp + cnt_r, right->d_columns_float[right->type_index[i]].begin());
						}
						else {
							str_gather(thrust::raw_pointer_cast(v.data()), cnt_r, (void*)right->d_columns_char[right->type_index[i]], (void*) thrust::raw_pointer_cast(d_tmp), right->char_size[right->type_index[i]]);
							cudaMemcpy( (void*)right->d_columns_char[right->type_index[i]], (void*) thrust::raw_pointer_cast(d_tmp), cnt_r*right->char_size[right->type_index[i]], cudaMemcpyDeviceToDevice);
						};
					};
				};
				ss.pop();
			};
			thrust::device_free(d_tmp);
		};

		if(right->d_columns_int[right->type_index[colInd2]][cnt_r-1] > std::numeric_limits<unsigned int>::max())
			v64bit = 1;
			
		colInd1 = (left->columnNames).find(f1)->second;			
		if (left->type[colInd1]  == 2) {
			cout << "Joins are not yet supported in star joins" << endl;
			exit(0);
		}
		else {
		    queue<string> cc;
			cc.push(f1);
			allocColumns(left, cc);
		};		
	
	    config.kInputSize = cnt_r;
		//cout << "creating table with " << cnt_r << " " << getFreeMem()  << endl;
		result = cudppHashTable(theCudpp, &hash_table_handle[i], &config);

		if (result == CUDPP_SUCCESS)
			cout << "hash tables created " << getFreeMem() << endl;
		
		
		if(left->maxRecs > rcount)
			tt = left->maxRecs;
		else {
		    if (rcount > tt)
				tt = rcount;
		};	
		thrust::device_vector<unsigned int> d_rr(tt);		
		thrust::device_vector<unsigned int> v(cnt_r);
		thrust::sequence(v.begin(),v.end(),0,1);
	
		thrust::copy(right->d_columns_int[right->type_index[colInd2]].begin(), right->d_columns_int[right->type_index[colInd2]].begin() + cnt_r,
					 d_rr.begin());				 
		result = cudppHashInsert(hash_table_handle[i], thrust::raw_pointer_cast(d_rr.data()),
								 thrust::raw_pointer_cast(v.data()), cnt_r);

		if (result == CUDPP_SUCCESS)
			cout << "hash table inserted " << getFreeMem() << endl;		
	
	};
	
	thrust::device_ptr<unsigned int> d_r = thrust::device_malloc<unsigned int>(tt);
	thrust::device_vector<unsigned int> d_s(tt);
	
	thrust::device_ptr<uint2> res = thrust::device_malloc<uint2>(left->maxRecs);
	
    thrust::device_vector<unsigned int> d_res1;
    thrust::device_vector<unsigned int> d_res2;
	
	thrust::device_vector<bool> d_star(left->maxRecs);
		
    unsigned int cnt_l, res_count, tot_count = 0, offset = 0, k = 0;
	string ttt;
	queue<string> lc;
		
	
    for (unsigned int i = 0; i < left->segCount; i++) {
	       
        cout << "segment " << i << " " << getFreeMem() <<  '\xd';		
	    thrust::sequence(d_star.begin(), d_star.end(),1,0);	

		   //for every hash table
	    queue<string> op_g1(op_value);
	    for(unsigned int z = 0; z < join_tab_cnt; z++) {			
			
	        cnt_l = 0;
			f1 = op_g1.front();
		    op_g1.pop();
		    f2 = op_g1.front();
		    op_g1.pop();	

			while(lc.size())
				lc.pop();
			lc.push(f1);			
			copyColumns(left, lc, i, cnt_l);
			already_copied[f1] = 1;
		
			if(left->prm.empty()) {
				cnt_l = left->mRecCount;
			}
			else {
				cnt_l = left->prm_count[i];
			};
			

            queue<string> op_jj(op_join);	
		    for(unsigned int j = 0; j < (join_tab_cnt-1) - z; j++) {
				op_jj.pop();
			};	
			
				
			unsigned int idx;	
			if (cnt_l) {								
				
				idx = left->type_index[left->columnNames[lc.front()]];	
				//cout << "left idx " << idx << endl;
				//cout << "right col " << op_jj.front() << endl;
                CudaSet* right = varNames.find(op_jj.front())->second;				
				colInd2 = right->columnNames[f2];

				thrust::copy(left->d_columns_int[idx].begin(), left->d_columns_int[idx].begin() + cnt_l, d_r);

                result = cudppHashRetrieve(hash_table_handle[z], thrust::raw_pointer_cast(d_r),
										   thrust::raw_pointer_cast(res), cnt_l);
				if (result != CUDPP_SUCCESS)
					cout << "Failed retrieve " << endl;

				uint2 rr = thrust::reduce(res, res+cnt_l, make_uint2(0,0), Uint2Sum());
			
	    
				res_count = rr.y;
				d_res1.resize(res_count);
				d_res2.resize(res_count);
				//cout << "res cnt of " << f2 << " = " << res_count << endl;

				if(res_count) {
					thrust::counting_iterator<unsigned int> begin(0);
					uint2_split ff(thrust::raw_pointer_cast(res),thrust::raw_pointer_cast(d_r));
					thrust::for_each(begin, begin + cnt_l, ff);
					
					if(!v64bit) {
						thrust::transform(d_star.begin(), d_star.begin() + cnt_l, d_r, d_star.begin(), thrust::logical_and<bool>());
					};

					thrust::exclusive_scan(d_r, d_r+cnt_l, d_r );  // addresses
					join_functor1 ff1(thrust::raw_pointer_cast(res),
									  thrust::raw_pointer_cast(d_r),
									  thrust::raw_pointer_cast(d_res1.data()),
									  thrust::raw_pointer_cast(d_res2.data()));
					thrust::for_each(begin, begin + cnt_l, ff1);
					
					if(v64bit) {// need to check the upper 32 bits
						thrust::device_ptr<bool> d_add = thrust::device_malloc<bool>(d_res1.size());
						thrust::permutation_iterator<ElementIterator_int,IndexIterator> iter_left(left->d_columns_int[idx].begin(), d_res1.begin());
						thrust::permutation_iterator<ElementIterator_int,IndexIterator> iter_right(right->d_columns_int[right->type_index[colInd2]].begin(), d_res2.begin());						
						thrust::transform(iter_left, iter_left+d_res2.size(), iter_right, d_add, int_upper_equal_to());
						unsigned int new_cnt = thrust::count(d_add, d_add+d_res1.size(), 1);
						if(new_cnt == 0)
							break;
						thrust::stable_partition(d_res1.begin(), d_res1.begin() + d_res2.size(), d_add, thrust::identity<unsigned int>());
						thrust::stable_partition(d_res2.begin(), d_res2.end(), d_add, thrust::identity<unsigned int>());
                        
						thrust::transform(d_star.begin(), d_star.end(), d_add, d_star.begin(), thrust::logical_and<bool>());
						thrust::device_free(d_add);
						d_res2.resize(new_cnt);
						d_res1.resize(new_cnt);
					
					};
                }
                else {
				    thrust::sequence(d_star.begin(), d_star.end(),0,0);	
					break;
				};	
            };			
		};	
        // if our bool vector is not all zeroes then load all left columns and also get indexes and gather values 
 		// from right hash tables	
		unsigned int n_cnt = thrust::count(d_star.begin(), d_star.begin() + cnt_l, 1);
		//cout << "Star join result count " << n_cnt << endl;
		tot_count = tot_count + n_cnt;
		queue<string> cc;
		if(n_cnt) { //gather		
		
			offset = c->mRecCount;
			if(i == 0 && left->segCount != 1) {
				c->reserve(n_cnt*(left->segCount+1));				
			};	
            c->resize_join(n_cnt);
            queue<string> op_sel1(op_sel_s);
            unsigned int colInd, c_colInd;
            
            while(!op_sel1.empty()) {
				
				
                while(!cc.empty())
                    cc.pop();

                cc.push(op_sel1.front());
				if(c->columnNames.find(op_sel1.front()) != c->columnNames.end()) {
                    c_colInd = c->columnNames[op_sel1.front()];						
				};	

                if(left->columnNames.find(op_sel1.front()) !=  left->columnNames.end()) {
                    // copy field's segment to device, gather it and copy to the host
                    colInd = left->columnNames[op_sel1.front()];
					//cout << "gathering left " << op_sel1.front() << endl;  
						
					if(already_copied.count(op_sel1.front()) == 0) {	
						reset_offsets();
						allocColumns(left, cc);
						copyColumns(left, cc, i, k);
					};	
					
                        //gather
                    if(left->type[colInd] == 0) {
						thrust::device_ptr<int_type> d_tmp = thrust::device_malloc<int_type>(n_cnt);
						thrust::copy_if(left->d_columns_int[left->type_index[colInd]].begin(), left->d_columns_int[left->type_index[colInd]].begin() + cnt_l,
						                d_star.begin(), d_tmp, thrust::identity<bool>());
						thrust::copy(d_tmp, d_tmp + n_cnt, c->h_columns_int[c->type_index[c_colInd]].begin() + offset);				
						thrust::device_free(d_tmp);				
                    }
                    else if(left->type[colInd] == 1) {
						thrust::device_ptr<float_type> d_tmp = thrust::device_malloc<float_type>(n_cnt);
						thrust::copy_if(left->d_columns_float[left->type_index[colInd]].begin(), left->d_columns_float[left->type_index[colInd]].begin() + cnt_l,
						                d_star.begin(), d_tmp, thrust::identity<bool>());						
                        thrust::copy(d_tmp, d_tmp + n_cnt, c->h_columns_float[c->type_index[c_colInd]].begin() + offset);
						thrust::device_free(d_tmp);				
                    }
                    else { //strings
                        thrust::device_ptr<char> d_tmp = thrust::device_malloc<char>(n_cnt*left->char_size[left->type_index[colInd]]);
						
						thrust::device_ptr<bool> d_g(thrust::raw_pointer_cast(d_star.data()));
						
                        str_copy_if(left->d_columns_char[left->type_index[colInd]], cnt_l, thrust::raw_pointer_cast(d_tmp),
						             d_g, c->char_size[c->type_index[c_colInd]]);
                        cudaMemcpy( (void*)&c->h_columns_char[c->type_index[c_colInd]][offset*c->char_size[c->type_index[c_colInd]]], (void*) thrust::raw_pointer_cast(d_tmp),
                                    c->char_size[c->type_index[c_colInd]] * n_cnt, cudaMemcpyDeviceToHost);
                        thrust::device_free(d_tmp);
                    }
                    //left->deAllocColumnOnDevice(colInd);

                }
                else { 
				
				    //cout << "gathering right " << op_sel1.front() << endl;  
                    string right_tab_name;
                    queue<string> op_j(op_join);	
		            while(!op_j.empty()) {
					    if(varNames[op_j.front()]->columnNames.count(op_sel1.front())) {
							right_tab_name = op_j.front();
							break;
						};
						op_j.pop();
					};	   
   
					colInd = left->columnNames[var_map[right_tab_name]];
					//cout << "leftcolind " << colInd << endl;
					
					CudaSet* right = varNames[right_tab_name];				
					unsigned int r_colInd = right->columnNames[op_sel1.front()];
					
					//cout << "rcolind " << r_colInd << endl;
					
	                while(!cc.empty())
						cc.pop();
                    cc.push(var_map[right_tab_name]);
					
					if(c->columnNames.find(op_sel1.front()) != c->columnNames.end()) {
						c_colInd = c->columnNames[op_sel1.front()];						
					};	
					
					if(already_copied.count(var_map[right_tab_name]) == 0) {
						reset_offsets();
						allocColumns(left, cc);
						copyColumns(left, cc, i, k);
					};	
					
					thrust::device_ptr<int_type> d_t = thrust::device_malloc<int_type>(n_cnt);
					thrust::copy_if(left->d_columns_int[left->type_index[colInd]].begin(), left->d_columns_int[left->type_index[colInd]].begin() + cnt_l,
					                d_star.begin(), d_t, thrust::identity<bool>());
									
                    // get the values from hash table
					unsigned int hash_ind = tab_map[right_tab_name];
					
					thrust::copy(d_t, d_t + n_cnt, d_r);
					thrust::device_free(d_t);	
					result = cudppHashRetrieve(hash_table_handle[hash_ind], thrust::raw_pointer_cast(d_r),
											thrust::raw_pointer_cast(res), n_cnt);					
					if (result != CUDPP_SUCCESS)
						cout << "Failed retrieve " << endl;
	
					thrust::counting_iterator<unsigned int> begin(0);
					uint2_split_left ff(thrust::raw_pointer_cast(res),thrust::raw_pointer_cast(d_s.data()));
					thrust::for_each(begin, begin + n_cnt, ff);	

                        //gather
					if(right->type[r_colInd] == 0) {
						thrust::permutation_iterator<ElementIterator_int,IndexIterator> iter(right->d_columns_int[right->type_index[r_colInd]].begin(), d_s.begin());
                        thrust::copy(iter, iter + n_cnt, c->h_columns_int[c->type_index[c_colInd]].begin() + offset);
                    }
                    else if(right->type[r_colInd] == 1) {
                        thrust::permutation_iterator<ElementIterator_float,IndexIterator> iter(right->d_columns_float[right->type_index[r_colInd]].begin(), d_s.begin());
                        thrust::copy(iter, iter + n_cnt, c->h_columns_float[c->type_index[c_colInd]].begin() + offset);
                    }
                    else { //strings
                        thrust::device_ptr<char> d_tmp1 = thrust::device_malloc<char>(n_cnt*right->char_size[right->type_index[r_colInd]]);
                        str_gather(thrust::raw_pointer_cast(d_s.data()), n_cnt, (void*)right->d_columns_char[right->type_index[r_colInd]],
                                   (void*) thrust::raw_pointer_cast(d_tmp1), right->char_size[right->type_index[r_colInd]]);
                        cudaMemcpy( (void*)(c->h_columns_char[c->type_index[c_colInd]] + offset*c->char_size[c->type_index[c_colInd]]), (void*) thrust::raw_pointer_cast(d_tmp1),
                                    c->char_size[c->type_index[c_colInd]] * n_cnt, cudaMemcpyDeviceToHost);
                        thrust::device_free(d_tmp1);
                    }
					//cout << "right gathered " << endl;
                }		
				
                op_sel1.pop();		
		    };
		};		
		
	};
	
    while(!op_join.empty()) {
		varNames[op_join.front()]->deAllocOnDevice();
		op_join.pop();
	};	   
	left->deAllocOnDevice();	
	
	for(unsigned int i = 0; i < join_tab_cnt; i++) {
		cudppDestroyHashTable(theCudpp, hash_table_handle[i]);
	};	
	delete [] hash_table_handle;
	
    varNames[s] = c;
    c->mRecCount = tot_count;
    c->maxRecs = tot_count;
	cout << endl << "join count " << tot_count << endl;
    for ( map<string,int>::iterator it=c->columnNames.begin() ; it != c->columnNames.end(); ++it ) {
        setMap[(*it).first] = s;			
	};	 
};


void emit_join(char *s, char *j1, int grp)
{

    statement_count++;
    if (scan_state == 0) {
        if (stat.find(j1) == stat.end()) {
            cout << "Join : couldn't find variable " << j1 << endl;
            exit(1);
        };
        if (stat.find(op_join.front()) == stat.end()) {
            cout << "Join : couldn't find variable " << op_join.front() << endl;
            exit(1);
        };
        stat[s] = statement_count;
        stat[j1] = statement_count;
		while(!op_join.empty()) {
            stat[op_join.front()] = statement_count;			
			op_join.pop();
		};		
        return;
    };


	queue<string> op_m(op_value);
      
    if(check_star_join(j1)) {	   
	    cout << "executing star join !! " << endl;
		star_join(s, j1);
    }
	else {
		if(join_tab_cnt > 1) {
			string tab_name;
			for(unsigned int i = 1; i <= join_tab_cnt; i++) {
	  
				if(i == join_tab_cnt)
					tab_name = s;
				else	 
					tab_name = s + to_string1((long long int)i);
			  
				string j, j2;	  
				if(i == 1) {	  		      
					j2 = op_join.front();
					op_join.pop();
					j = op_join.front();
					op_join.pop();
				}
				else {
					if(!op_join.empty()) {
						j = op_join.front();	
						op_join.pop();
					}	
					else
						j = j1;			  					
					j2 = s + to_string1((long long int)i-1);
				};
				emit_multijoin(tab_name, j, j2, i, s);
				op_value = op_m;
			};	
		}
		else {
			string j2 = op_join.front();	
			op_join.pop();
			emit_multijoin(s, j1, j2, 1, s);
		}; 
    };		
	
    clean_queues();
   
    if(stat[s] == statement_count) {
        varNames[s]->free();
        varNames.erase(s);
    };

    if(stat[j1] == statement_count) {
        varNames[j1]->free();
        varNames.erase(j1);
    };

    if(stat[op_join.front()] == statement_count && op_join.front().compare(j1) != 0) {
        varNames[op_join.front()]->free();
        varNames.erase(op_join.front());
    };
   
}

bool show = 0;

void emit_multijoin(string s, string j1, string j2, unsigned int tab, char* res_name)
{

	//cout << "j2 " << j2 << endl;
	//cout << "j1 " << j1 << endl;
    

    if(varNames.find(j1) == varNames.end() || varNames.find(j2) == varNames.end()) {
        clean_queues();
		if(varNames.find(j1) == varNames.end())
		    cout << "Couldn't find j1 " << j1 << endl;
		if(varNames.find(j2) == varNames.end())
		    cout << "Couldn't find j2 " << j2 << endl;

        return;
    };

    CudaSet* left = varNames.find(j1)->second;
    CudaSet* right = varNames.find(j2)->second;
	

    queue<string> op_sel;
    queue<string> op_sel_as;
    for(int i=0; i < sel_count; i++) {
        op_sel.push(op_value.front());
        op_value.pop();
        op_sel_as.push(op_value.front());
        op_value.pop();
    };
	
	queue<string> op_sel_s(op_sel);
	queue<string> op_sel_s_as(op_sel_as);
	queue<string> op_g(op_value);	
	
	//cout << "join_col_cnt " << join_col_cnt << endl;			 
	if(tab > 0) {			
	    for(unsigned int z = 0; z < join_tab_cnt - tab; z++) {
			for(unsigned int j = 0; j < join_and_cnt[z]*2 + 2; j++) {
				op_sel_s.push(op_g.front());
				op_sel_s_as.push(op_g.front());						
				op_g.pop();	
			};		
		};
	};
	

    string f1 = op_g.front();
    op_g.pop();
    string f2 = op_g.front();
    op_g.pop();

    cout << "JOIN " << s <<  " " <<  f1 << " " << f2 << " " << getFreeMem() <<  endl;
	
    std::clock_t start1 = std::clock();
	//cout << "creating c with " << op_sel.size() << endl;
	if(tab != join_tab_cnt) {
	//	op_sel_s.push(f1);
	//	op_sel_s.push(f2);
	//	op_sel_s_as.push(f1);
	//	op_sel_s_as.push(f2);
	};	
	
		
    CudaSet* c = new CudaSet(right, left, op_sel_s, op_sel_s_as);

    if (left->mRecCount == 0 || right->mRecCount == 0) {
        c = new CudaSet(left, right, op_sel_s, op_sel_s_as);
        varNames[res_name] = c;
        clean_queues();
        cout << "Join result " << res_name << " : " << c->mRecCount << endl; 		
        return;
    };
	
	if(join_tab_cnt > 1 && tab < join_tab_cnt)
	    c->tmp_table = 1;
	else
        c->tmp_table = 0;	

    unsigned int colInd1, colInd2;
    string tmpstr;
    if (left->columnNames.find(f1) != left->columnNames.end()) {
        colInd1 = (left->columnNames).find(f1)->second;
        if (right->columnNames.find(f2) != right->columnNames.end()) {
            colInd2 = (right->columnNames).find(f2)->second;
        }
        else {
            cout << "Couldn't find column " << f2 << endl;
            exit(0);
        };
    }
    else if (right->columnNames.find(f1) != right->columnNames.end()) {
        colInd2 = (right->columnNames).find(f1)->second;
        tmpstr = f1;
        f1 = f2;
        if (left->columnNames.find(f2) != left->columnNames.end()) {
            colInd1 = (left->columnNames).find(f2)->second;
            f2 = tmpstr;
        }
        else {
            cout << "Couldn't find column " << f2 << endl;
            exit(0);
        };
    }
    else {
        cout << "Couldn't find column " << f1 << endl;
        exit(0);
    };


    if (!((left->type[colInd1] == 0 && right->type[colInd2]  == 0) || (left->type[colInd1] == 2 && right->type[colInd2]  == 2)
            || (left->type[colInd1] == 1 && right->type[colInd2]  == 1 && left->decimal[colInd1] && right->decimal[colInd2]))) {
        cout << "Joins on floats are not supported " << endl;
        exit(0);
    };
    bool decimal_join = 0;
    if (left->type[colInd1] == 1 && right->type[colInd2]  == 1)
        decimal_join = 1;

    set<string> field_names;
    stack<string> exe_type;
    exe_type.push(f2);
    field_names.insert(f2);

    bool str_join = 0;
	unsigned int cnt_r;
    //if join is on strings then add integer columns to left and right tables and modify colInd1 and colInd2

    if (right->type[colInd2]  == 2) {
        str_join = 1;
        right->d_columns_int.push_back(thrust::device_vector<int_type>());
        for(unsigned int i = 0; i < right->segCount; i++) {
            right->add_hashed_strings(f2, i, right->d_columns_int.size()-1);
        };
		cnt_r = right->d_columns_int[right->d_columns_int.size()-1].size();
    };

    // need to allocate all right columns
    queue<string> cc;
    unsigned int rcount;
    curr_segment = 10000000;


    queue<string> op_vd(op_g);
    queue<string> op_alt(op_sel);
    unsigned int jc = join_and_cnt[join_tab_cnt - tab];
    while(jc) {
        jc--;
        op_vd.pop();
        op_alt.push(op_vd.front());
        op_vd.pop();
    };

	
	string empty = "";
	if(right->not_compressed) {
	    queue<string> op_alt1;
		op_alt1.push(f2);
		cnt_r = load_queue(op_alt1, right, str_join, empty, rcount);
	}
	else {
		cnt_r = load_queue(op_alt, right, str_join, f2, rcount);
	};	
	
    if(str_join) {
        colInd2 = right->mColumnCount+1;
        right->type_index[colInd2] = right->d_columns_int.size()-1;
    };


    //here we need to make sure that right column is ordered. If not then we order it and keep the permutation
	
	thrust::device_ptr<unsigned long long int> d_col_r((unsigned long long int*)thrust::raw_pointer_cast(right->d_columns_int[right->type_index[colInd2]].data()));					
	
    bool sorted;
	
	if(str_join) {
	    sorted = thrust::is_sorted(d_col_r, d_col_r + cnt_r);
	}	
    else if(!decimal_join) {        
		sorted = thrust::is_sorted(right->d_columns_int[right->type_index[colInd2]].begin(), right->d_columns_int[right->type_index[colInd2]].begin() + cnt_r);
	}	
    else
        sorted = thrust::is_sorted(right->d_columns_float[right->type_index[colInd2]].begin(), right->d_columns_float[right->type_index[colInd2]].begin() + cnt_r);


			
    if(!sorted) {

	    typedef thrust::device_ptr<unsigned int> IndexIterator2;
        queue<string> ss(op_sel);
		thrust::device_ptr<unsigned int> v = thrust::device_malloc<unsigned int>(cnt_r);
        thrust::sequence(v, v + cnt_r, 0, 1);	

		unsigned int max_c	= max_char(right);
        unsigned int mm;
        if(max_c > 8)
            mm = max_c;
        else
            mm = 8;        
        void* d;
        CUDA_SAFE_CALL(cudaMalloc((void **) &d, cnt_r*mm)); 		

		if(str_join) {
			thrust::sort_by_key(d_col_r, d_col_r + cnt_r, v);
		}	
		else {
			thrust::sort_by_key(right->d_columns_int[right->type_index[colInd2]].begin(), right->d_columns_int[right->type_index[colInd2]].begin() + cnt_r, v);
		};				

        unsigned int i;
        while(!ss.empty()) {
            if (right->columnNames.find(ss.front()) != right->columnNames.end()) {
                i = right->columnNames[ss.front()];

                if(i != colInd2) {
				
					if(right->not_compressed) {		
					    queue<string> op_alt1;
						op_alt1.push(ss.front());	
						cnt_r = load_queue(op_alt1, right, str_join, empty, rcount);
						
					};							

                    if(right->type[i] == 0) {
					    thrust::device_ptr<int_type> d_tmp((int_type*)d);
                        thrust::gather(v, v+cnt_r, right->d_columns_int[right->type_index[i]].begin(), d_tmp);
                        thrust::copy(d_tmp, d_tmp + cnt_r, right->d_columns_int[right->type_index[i]].begin());
                    }
                    else if(right->type[i] == 1) {
					    thrust::device_ptr<float_type> d_tmp((float_type*)d);
                        thrust::gather(v, v+cnt_r, right->d_columns_float[right->type_index[i]].begin(), d_tmp);
                        thrust::copy(d_tmp, d_tmp + cnt_r, right->d_columns_float[right->type_index[i]].begin());
                    }
                    else {
					    thrust::device_ptr<char> d_tmp((char*)d);
                        str_gather(thrust::raw_pointer_cast(v), cnt_r, (void*)right->d_columns_char[right->type_index[i]], (void*) thrust::raw_pointer_cast(d_tmp), right->char_size[right->type_index[i]]);
                        cudaMemcpy( (void*)right->d_columns_char[right->type_index[i]], (void*) thrust::raw_pointer_cast(d_tmp), cnt_r*right->char_size[right->type_index[i]], cudaMemcpyDeviceToDevice);
                    };
                };
            };
            ss.pop();
        };
		thrust::device_free(v);
		cudaFree(d);
    }
    else {
		if(right->not_compressed) {
			queue<string> op_alt1;
			while(!op_alt.empty()) {
				if(f2.compare(op_alt.front())) {
					if (right->columnNames.find(op_alt.front()) != right->columnNames.end()) {
						op_alt1.push(op_alt.front());
					};	
				};	
				op_alt.pop();	
			};
			cnt_r = load_queue(op_alt1, right, str_join, empty, rcount);			
		};
    };	
	
   

    while(!cc.empty())
        cc.pop();

    if (left->type[colInd1]  == 2) {
        left->d_columns_int.push_back(thrust::device_vector<int_type>());
    }
    else {
        cc.push(f1);
        allocColumns(left, cc);
    };
	
	
	left->oldRecCount = left->mRecCount;
	
    unsigned int cnt_l, res_count, tot_count = 0, offset = 0, k = 0;
    queue<string> lc(cc);
    curr_segment = 10000000;	
	thrust::device_vector<int> p_tmp;	
	thrust::device_vector<unsigned int> v_l(left->maxRecs);		
	MGPU_MEM(int) aIndicesDevice, bIndicesDevice;			

    for (unsigned int i = 0; i < left->segCount; i++) {

        cout << "segment " << i <<  '\xd';
				
        cnt_l = 0;
		
        if (left->type[colInd1]  != 2) {
            copyColumns(left, lc, i, cnt_l);		
        }
        else {
		    //left->d_columns_int.resize(0);
            left->add_hashed_strings(f1, i, left->d_columns_int.size()-1);
        };		
		
		
	    if(left->prm.empty()) {
            //copy all records
			if (left->type[colInd1]  != 2) 
				cnt_l = left->mRecCount;
			else
				cnt_l = left->d_columns_int[left->d_columns_int.size()-1].size();
        }
        else {
            cnt_l = left->prm_count[i];
        };
		
	
        if (cnt_l) {
 
            unsigned int idx;
            if(!str_join)
                idx = left->type_index[colInd1];
            else
                idx = left->d_columns_int.size()-1;				
				
			// sort the left index column, save the permutation vector, it might be needed later
			
			thrust::sequence(v_l.begin(), v_l.begin() + cnt_l,0,1);
			
			thrust::device_ptr<unsigned long long int> d_col((unsigned long long int*)thrust::raw_pointer_cast(left->d_columns_int[idx].data()));					
			bool do_sort = 1;
			if(!left->sorted_fields.empty()) {
				if(left->sorted_fields.front() == idx) {
					do_sort = 0;
				};	
			}
			if(do_sort)
				thrust::sort_by_key(d_col, d_col + cnt_l, v_l.begin());			    						
		    //cout << endl << "j1 " << getFreeMem() << endl;
			//cout << "join " << cnt_l << ":" << cnt_r << " " << join_type.front() << endl;
			//cout << "MIN MAX " << left->d_columns_int[idx][0] << " - " << left->d_columns_int[idx][cnt_l-1] << " : " << right->d_columns_int[right->type_index[colInd2]][0] << "-" << right->d_columns_int[right->type_index[colInd2]][cnt_r-1] << endl; 
			
			
			char join_kind = join_type.front();
			join_type.pop();			

			
			if (left->type[colInd1] == 2) {
					res_count = RelationalJoin<MgpuJoinKindInner>(thrust::raw_pointer_cast(d_col), cnt_l,
									thrust::raw_pointer_cast(d_col_r), cnt_r,
									&aIndicesDevice, &bIndicesDevice,
									mgpu::less<unsigned long long int>(), *context);
														
			}
			else {

				if (join_kind == 'I')
					res_count = RelationalJoin<MgpuJoinKindInner>(thrust::raw_pointer_cast(left->d_columns_int[idx].data()), cnt_l,
									thrust::raw_pointer_cast(right->d_columns_int[right->type_index[colInd2]].data()), cnt_r,
									&aIndicesDevice, &bIndicesDevice,
									mgpu::less<int_type>(), *context);
				else if(join_kind == 'L')					
					res_count = RelationalJoin<MgpuJoinKindLeft>(thrust::raw_pointer_cast(left->d_columns_int[idx].data()), cnt_l,
									thrust::raw_pointer_cast(right->d_columns_int[right->type_index[colInd2]].data()), cnt_r,
									&aIndicesDevice, &bIndicesDevice,
									mgpu::less<int_type>(), *context);
				else if(join_kind == 'R')					
					res_count = RelationalJoin<MgpuJoinKindRight>(thrust::raw_pointer_cast(left->d_columns_int[idx].data()), cnt_l,
									thrust::raw_pointer_cast(right->d_columns_int[right->type_index[colInd2]].data()), cnt_r,
									&aIndicesDevice, &bIndicesDevice,
									mgpu::less<int_type>(), *context);
				else if(join_kind == 'O')					
					res_count = RelationalJoin<MgpuJoinKindOuter>(thrust::raw_pointer_cast(left->d_columns_int[idx].data()), cnt_l,
									thrust::raw_pointer_cast(right->d_columns_int[right->type_index[colInd2]].data()), cnt_r,
									&aIndicesDevice, &bIndicesDevice,
									mgpu::less<int_type>(), *context);								
			};	

		
			//cout << "total " << res_count << endl;
			int* r1 = aIndicesDevice->get(); 
            thrust::device_ptr<int> d_res1((int*)r1);
			int* r2 = bIndicesDevice->get(); 
			thrust::device_ptr<int> d_res2((int*)r2);		
		
			if(res_count) {						
				p_tmp.resize(res_count);
				thrust::sequence(p_tmp.begin(), p_tmp.end(),-1);
				thrust::gather_if(d_res1, d_res1+res_count, d_res1, v_l.begin(), p_tmp.begin(), is_positive());		
			};		
			
		
			//std::cout<< endl << "join time " <<  ( ( std::clock() - start3 ) / (double)CLOCKS_PER_SEC ) << " " << getFreeMem() << endl;            
	
            // check if the join is a multicolumn join
			unsigned int mul_cnt = join_and_cnt[join_tab_cnt - tab];
			while(mul_cnt) {			
			    		    
                mul_cnt--;
                string f3 = op_g.front();
                op_g.pop();
                string f4 = op_g.front();
                op_g.pop();
				
				//cout << "ADDITIONAL COL JOIN " << f3 << " " << f4 << " " << getFreeMem() << endl;
			
                queue<string> rc;
                rc.push(f3);

                allocColumns(left, rc);
                copyColumns(left, rc, i, cnt_l);
                rc.pop();	
				
		        void* temp;
				CUDA_SAFE_CALL(cudaMalloc((void **) &temp, res_count*float_size));
		        void* temp1;
				CUDA_SAFE_CALL(cudaMalloc((void **) &temp1, res_count*float_size));
				cudaMemset(temp,0,res_count);
				cudaMemset(temp1,0,res_count);

                				
                if (res_count) {
				    unsigned int new_cnt;
                    unsigned int colInd3 = (left->columnNames).find(f3)->second;
                    unsigned int colInd4 = (right->columnNames).find(f4)->second;    
					thrust::device_ptr<bool> d_add = thrust::device_malloc<bool>(res_count);
					
                    if (left->type[colInd3] == 1 && right->type[colInd4]  == 1) {
					
                        if(right->d_columns_float[right->type_index[colInd4]].size() == 0)
                            unsigned int cnt_r = load_queue(rc, right, 0, f4, rcount);									
		                
						thrust::device_ptr<float_type> d_tmp((float_type*)temp);	
						thrust::device_ptr<float_type> d_tmp1((float_type*)temp1);	
		                thrust::gather_if(p_tmp.begin(), p_tmp.end(), p_tmp.begin(), left->d_columns_float[left->type_index[colInd3]].begin(), d_tmp, is_positive());						
                        thrust::gather_if(d_res2, d_res2+res_count, d_res2, right->d_columns_float[right->type_index[colInd4]].begin(), d_tmp1, is_positive());																		
						thrust::transform(d_tmp, d_tmp+res_count, d_tmp1, d_add, float_equal_to());
                    }
                    else {
                        if(right->d_columns_int[right->type_index[colInd4]].size() == 0) {
                            unsigned int cnt_r = load_queue(rc, right, 0, f4, rcount);		
			            };                        					
						thrust::device_ptr<int_type> d_tmp((int_type*)temp);	
						thrust::device_ptr<int_type> d_tmp1((int_type*)temp1);	
		                thrust::gather_if(p_tmp.begin(), p_tmp.end(), p_tmp.begin(), left->d_columns_int[left->type_index[colInd3]].begin(), d_tmp, is_positive());						
                        thrust::gather_if(d_res2, d_res2+res_count, d_res2, right->d_columns_int[right->type_index[colInd4]].begin(), d_tmp1, is_positive());												
                        thrust::transform(d_tmp, d_tmp+res_count, d_tmp1, d_add, thrust::equal_to<int_type>());
                    };

					if (join_kind == 'I') {  // result count changes only in case of an inner join
						new_cnt = thrust::count(d_add, d_add+res_count, 1);	
						thrust::stable_partition(d_res2, d_res2 + res_count, d_add, thrust::identity<unsigned int>());
						thrust::stable_partition(p_tmp.begin(), p_tmp.end(), d_add, thrust::identity<unsigned int>());
						thrust::device_free(d_add);						
						res_count = new_cnt;
					}
					else { //otherwise we consider it a valid left join result with non-nulls on the left side and nulls on the right side
						thrust::transform(d_res2, d_res2 + res_count, d_add , d_res2, set_minus());	
					};
                };
				cudaFree(temp);
				cudaFree(temp1);				
            };			
            
            tot_count = tot_count + res_count;			
		
			
            if(res_count) {			

                offset = c->mRecCount;
                if(i == 0 && left->segCount != 1) {
                    c->reserve(res_count*(left->segCount+1));
				};	
                c->resize_join(res_count);	
				
				
                queue<string> op_sel1(op_sel_s);
                unsigned int colInd, c_colInd;
				
								
		        void* temp;
				unsigned int max_c = max_char(c);
		
				if(max_c > float_size) {
					CUDA_SAFE_CALL(cudaMalloc((void **) &temp, res_count*max_c));
				}	
				else
					CUDA_SAFE_CALL(cudaMalloc((void **) &temp, res_count*float_size));
					
               
                while(!op_sel1.empty()) {
				
			
                    while(!cc.empty())
                        cc.pop();

                    cc.push(op_sel1.front());
					if(c->columnNames.find(op_sel1.front()) != c->columnNames.end()) {
                        c_colInd = c->columnNames[op_sel1.front()];						
					};	
					
					if(left->columnNames.find(op_sel1.front()) !=  left->columnNames.end()) {
                        // copy field's segment to device, gather it and copy to the host
                        colInd = left->columnNames[op_sel1.front()];						
                    
                        reset_offsets();	
                        allocColumns(left, cc);
                        copyColumns(left, cc, i, k);//possible that in some cases a join column would be copied to device twice					
						
                        //gather
                        if(left->type[colInd] == 0) {
							thrust::device_ptr<int_type> d_tmp((int_type*)temp);	
							thrust::sequence(d_tmp, d_tmp+res_count,0,0);
                            //thrust::permutation_iterator<ElementIterator_int,IndexIterator> iter(left->d_columns_int[left->type_index[colInd]].begin(), p_tmp.begin());
							thrust::gather_if(p_tmp.begin(), p_tmp.begin() + res_count, p_tmp.begin(), left->d_columns_int[left->type_index[colInd]].begin(), d_tmp, is_positive());							
							thrust::copy(d_tmp, d_tmp + res_count, c->h_columns_int[c->type_index[c_colInd]].begin() + offset);							
                        }
                        else if(left->type[colInd] == 1) {
						    thrust::device_ptr<float_type> d_tmp((float_type*)temp);	
							thrust::sequence(d_tmp, d_tmp+res_count,0,0);
                            //thrust::permutation_iterator<ElementIterator_float,IndexIterator> iter(left->d_columns_float[left->type_index[colInd]].begin(), p_tmp.begin());
							thrust::gather_if(p_tmp.begin(), p_tmp.begin() + res_count, p_tmp.begin(), left->d_columns_float[left->type_index[colInd]].begin(), d_tmp, is_positive());
                            thrust::copy(d_tmp, d_tmp + res_count, c->h_columns_float[c->type_index[c_colInd]].begin() + offset);
                        }
                        else { //strings
                            thrust::device_ptr<char> d_tmp((char*)temp);							
						
							thrust::fill(d_tmp, d_tmp+res_count*left->char_size[left->type_index[colInd]],0);
                            str_gather(thrust::raw_pointer_cast(p_tmp.data()), res_count, (void*)left->d_columns_char[left->type_index[colInd]],
                                       (void*) thrust::raw_pointer_cast(d_tmp), left->char_size[left->type_index[colInd]]);
									   
									   
                            cudaMemcpy( (void*)&c->h_columns_char[c->type_index[c_colInd]][offset*c->char_size[c->type_index[c_colInd]]], (void*) thrust::raw_pointer_cast(d_tmp),
                                        c->char_size[c->type_index[c_colInd]] * res_count, cudaMemcpyDeviceToHost);
                        };
						if(colInd != colInd1)
							left->deAllocColumnOnDevice(colInd);

                    }
                    else if(right->columnNames.find(op_sel1.front()) !=  right->columnNames.end()) {
                        colInd = right->columnNames[op_sel1.front()];

                        //gather
                        if(right->type[colInd] == 0) {			
							thrust::device_ptr<int_type> d_tmp((int_type*)temp);	
							thrust::sequence(d_tmp, d_tmp+res_count,0,0);
                            //thrust::permutation_iterator<ElementIterator_int,IndexIterator1> iter(right->d_columns_int[right->type_index[colInd]].begin(), d_res2);
							thrust::gather_if(d_res2, d_res2 + res_count, d_res2, right->d_columns_int[right->type_index[colInd]].begin(), d_tmp, is_positive());
                            thrust::copy(d_tmp, d_tmp + res_count, c->h_columns_int[c->type_index[c_colInd]].begin() + offset);
                        }
                        else if(right->type[colInd] == 1) {
   						    thrust::device_ptr<float_type> d_tmp((float_type*)temp);	
							thrust::sequence(d_tmp, d_tmp+res_count,0,0);
                            //thrust::permutation_iterator<ElementIterator_float,IndexIterator1> iter(right->d_columns_float[right->type_index[colInd]].begin(), d_res2);
							thrust::gather_if(d_res2, d_res2 + res_count, d_res2, right->d_columns_float[right->type_index[colInd]].begin(), d_tmp, is_positive());
                            thrust::copy(d_tmp, d_tmp + res_count, c->h_columns_float[c->type_index[c_colInd]].begin() + offset);							
                        }
                        else { //strings						
						
	                        thrust::device_ptr<char> d_tmp((char*)temp);
							thrust::sequence(d_tmp, d_tmp+res_count*right->char_size[right->type_index[colInd]],0,0);					
                            str_gather(thrust::raw_pointer_cast(d_res2), res_count, (void*)right->d_columns_char[right->type_index[colInd]],
                                       (void*) thrust::raw_pointer_cast(d_tmp), right->char_size[right->type_index[colInd]]);																   						   										

							
                            cudaMemcpy( (void*)&c->h_columns_char[c->type_index[c_colInd]][offset*c->char_size[c->type_index[c_colInd]]], (void*) thrust::raw_pointer_cast(d_tmp),
                                        c->char_size[c->type_index[c_colInd]] * res_count, cudaMemcpyDeviceToHost);		

					
                        };						
                    }
                    else {
                        //cout << "Couldn't find field " << op_sel1.front() << endl;
                        //exit(0);
                    };
                    op_sel1.pop();					
                };
				cudaFree(temp);				
            };	
        };		
    };	
	
		

    left->deAllocOnDevice();
    right->deAllocOnDevice();
    c->deAllocOnDevice();	

    unsigned int i = 0;	
    while(!col_aliases.empty() && tab == join_tab_cnt) {
        c->columnNames[col_aliases.front()] = i;
        col_aliases.pop();
        i++;
    };

    varNames[s] = c;
    c->mRecCount = tot_count;
    c->maxRecs = tot_count;
	cout << endl << "join count " << tot_count << endl;
    for ( map<string,int>::iterator it=c->columnNames.begin() ; it != c->columnNames.end(); ++it )
        setMap[(*it).first] = s;

    if(right->tmp_table == 1) {
        varNames[j2]->free();
        varNames.erase(j2);
	};
	
	//printf("total cpy Time :  %3.1f ms \n", total_ctime);
	//printf("total half Time :  %3.1f ms \n", half);
	//printf("total Time :  %3.1f ms \n", total_time);
	//printf("total mmm :  %3.1f ms \n", mmm);
	//printf("total gather Time :  %3.1f ms \n", total_gtime);
	
    std::cout<< "join time " <<  ( ( std::clock() - start1 ) / (double)CLOCKS_PER_SEC ) << " " << getFreeMem() << endl;
	
}


void order_on_host(CudaSet *a, CudaSet* b, queue<string> names, stack<string> exe_type, stack<string> exe_value)
{
    unsigned int tot = 0;
    if(!a->not_compressed) { //compressed
        allocColumns(a, names);

        unsigned int c = 0;
        if(a->prm_count.size())	{
            for(unsigned int i = 0; i < a->prm.size(); i++)
                c = c + a->prm_count[i];
        }
        else
            c = a->mRecCount;
        a->mRecCount = 0;
        a->resize(c);

        unsigned int cnt = 0;
        for(unsigned int i = 0; i < a->segCount; i++) {
            copyColumns(a, names, (a->segCount - i) - 1, cnt);	//uses segment 1 on a host	to copy data from a file to gpu
            if (a->mRecCount) {
                a->CopyToHost((c - tot) - a->mRecCount, a->mRecCount);
                tot = tot + a->mRecCount;
            };
        };
    }
    else
        tot = a->mRecCount;

    b->resize(tot); //resize host arrays
    a->mRecCount = tot;

    unsigned int* permutation = new unsigned int[a->mRecCount];
    thrust::sequence(permutation, permutation + a->mRecCount);

    unsigned int maxSize =  a->mRecCount;
    char* temp;
    unsigned int max_c = max_char(a);

    if(max_c > float_size)
        temp = new char[maxSize*max_c];
    else
        temp = new char[maxSize*float_size];

    // sort on host

    for(int i=0; !exe_type.empty(); ++i, exe_type.pop(),exe_value.pop()) {
        int colInd = (a->columnNames).find(exe_type.top())->second;

        if ((a->type)[colInd] == 0)
            update_permutation_host(a->h_columns_int[a->type_index[colInd]].data(), permutation, a->mRecCount, exe_value.top(), (int_type*)temp);
        else if ((a->type)[colInd] == 1)
            update_permutation_host(a->h_columns_float[a->type_index[colInd]].data(), permutation, a->mRecCount,exe_value.top(), (float_type*)temp);
        else {
            update_permutation_char_host(a->h_columns_char[a->type_index[colInd]], permutation, a->mRecCount, exe_value.top(), b->h_columns_char[b->type_index[colInd]], a->char_size[a->type_index[colInd]]);
        };
    };

    for (unsigned int i = 0; i < a->mColumnCount; i++) {
        if ((a->type)[i] == 0) {
            apply_permutation_host(a->h_columns_int[a->type_index[i]].data(), permutation, a->mRecCount, b->h_columns_int[b->type_index[i]].data());
        }
        else if ((a->type)[i] == 1)
            apply_permutation_host(a->h_columns_float[a->type_index[i]].data(), permutation, a->mRecCount, b->h_columns_float[b->type_index[i]].data());
        else {
            apply_permutation_char_host(a->h_columns_char[a->type_index[i]], permutation, a->mRecCount, b->h_columns_char[b->type_index[i]], a->char_size[a->type_index[i]]);
        };
    };
	
    delete [] temp;
    delete [] permutation;
}



void emit_order(char *s, char *f, int e, int ll)
{
    if(ll == 0)
        statement_count++;

    if (scan_state == 0 && ll == 0) {
        if (stat.find(f) == stat.end()) {
            cout << "Order : couldn't find variable " << f << endl;
            exit(1);
        };
        stat[s] = statement_count;
        stat[f] = statement_count;
        return;
    };

    if(varNames.find(f) == varNames.end() ) {
        clean_queues();
        return;
    };

    CudaSet* a = varNames.find(f)->second;


    if (a->mRecCount == 0)	{
        if(varNames.find(s) == varNames.end())
            varNames[s] = new CudaSet(0,1);
        else {
            CudaSet* c = varNames.find(s)->second;
            c->mRecCount = 0;
        };
        return;
    };

    stack<string> exe_type, exe_value;

    cout << "order: " << s << " " << f << endl;


    for(int i=0; !op_type.empty(); ++i, op_type.pop(),op_value.pop()) {
        if ((op_type.front()).compare("NAME") == 0) {
            exe_type.push(op_value.front());
            exe_value.push("ASC");
        }
        else {
            exe_type.push(op_type.front());
            exe_value.push(op_value.front());
        };
    };

    stack<string> tp(exe_type);
    queue<string> op_vx;
    while (!tp.empty()) {
        op_vx.push(tp.top());
        tp.pop();
    };

    queue<string> names;
    for ( map<string,int>::iterator it=a->columnNames.begin() ; it != a->columnNames.end(); ++it )
        names.push((*it).first);

    CudaSet *b = a->copyDeviceStruct();

    //lets find out if our data set fits into a GPU
    size_t mem_available = getFreeMem();
    size_t rec_size = 0;
    for(unsigned int i = 0; i < a->mColumnCount; i++) {
        if(a->type[i] == 0)
            rec_size = rec_size + int_size;
        else if(a->type[i] == 1)
            rec_size = rec_size + float_size;
        else
            rec_size = rec_size + a->char_size[a->type_index[i]];
    };
    bool fits;
    if (rec_size*a->mRecCount > (mem_available/2)) // doesn't fit into a GPU
        fits = 0;
    else fits = 1;

    if(!fits) {
        order_on_host(a, b, names, exe_type, exe_value);
    }
    else {
        // initialize permutation to [0, 1, 2, ... ,N-1]
        thrust::device_ptr<unsigned int> permutation = thrust::device_malloc<unsigned int>(a->mRecCount);
        thrust::sequence(permutation, permutation+(a->mRecCount));

        unsigned int* raw_ptr = thrust::raw_pointer_cast(permutation);

        unsigned int maxSize =  a->mRecCount;
        void* temp;
        unsigned int max_c = max_char(a);

        if(max_c > float_size)
            CUDA_SAFE_CALL(cudaMalloc((void **) &temp, maxSize*max_c));
        else
            CUDA_SAFE_CALL(cudaMalloc((void **) &temp, maxSize*float_size));

        varNames[setMap[exe_type.top()]]->oldRecCount = varNames[setMap[exe_type.top()]]->mRecCount;


        unsigned int rcount;

        a->mRecCount = load_queue(names, a, 1, op_vx.front(), rcount);

        varNames[setMap[exe_type.top()]]->mRecCount = varNames[setMap[exe_type.top()]]->oldRecCount;
        //unsigned int str_count = 0;

        for(int i=0; !exe_type.empty(); ++i, exe_type.pop(),exe_value.pop()) {
            int colInd = (a->columnNames).find(exe_type.top())->second;
            if ((a->type)[colInd] == 0)
                update_permutation(a->d_columns_int[a->type_index[colInd]], raw_ptr, a->mRecCount, exe_value.top(), (int_type*)temp);
            else if ((a->type)[colInd] == 1)
                update_permutation(a->d_columns_float[a->type_index[colInd]], raw_ptr, a->mRecCount,exe_value.top(), (float_type*)temp);
            else {
                update_permutation_char(a->d_columns_char[a->type_index[colInd]], raw_ptr, a->mRecCount, exe_value.top(), (char*)temp, a->char_size[a->type_index[colInd]]);
                //update_permutation(a->d_columns_int[int_col_count+str_count], raw_ptr, a->mRecCount, exe_value.top(), (int_type*)temp);
                //str_count++;
            };
        };

        b->resize(a->mRecCount); //resize host arrays
        b->mRecCount = a->mRecCount;
        //str_count = 0;

        for (unsigned int i = 0; i < a->mColumnCount; i++) {
            if ((a->type)[i] == 0)
                apply_permutation(a->d_columns_int[a->type_index[i]], raw_ptr, a->mRecCount, (int_type*)temp);
            else if ((a->type)[i] == 1)
                apply_permutation(a->d_columns_float[a->type_index[i]], raw_ptr, a->mRecCount, (float_type*)temp);
            else {				
                apply_permutation_char(a->d_columns_char[a->type_index[i]], raw_ptr, a->mRecCount, (char*)temp, a->char_size[a->type_index[i]]);
				//str_count++;
            };
        };

        for(unsigned int i = 0; i < a->mColumnCount; i++) {
            switch(a->type[i]) {
            case 0 :
                thrust::copy(a->d_columns_int[a->type_index[i]].begin(), a->d_columns_int[a->type_index[i]].begin() + a->mRecCount, b->h_columns_int[b->type_index[i]].begin());
                break;
            case 1 :
                thrust::copy(a->d_columns_float[a->type_index[i]].begin(), a->d_columns_float[a->type_index[i]].begin() + a->mRecCount, b->h_columns_float[b->type_index[i]].begin());
                break;
            default :
                cudaMemcpy(b->h_columns_char[b->type_index[i]], a->d_columns_char[a->type_index[i]], a->char_size[a->type_index[i]]*a->mRecCount, cudaMemcpyDeviceToHost);
            }
        };

        b->deAllocOnDevice();
        a->deAllocOnDevice();


        thrust::device_free(permutation);
        cudaFree(temp);
    };

    varNames[s] = b;
    b->segCount = 1;
    b->not_compressed = 1;

    if(stat[f] == statement_count && !a->keep) {
        a->free();
        varNames.erase(f);
    };
}


void emit_select(char *s, char *f, int ll)
{
    statement_count++;
    if (scan_state == 0) {
        if (stat.find(f) == stat.end()) {
            cout << "Select : couldn't find variable " << f << endl;
            exit(1);
        };
        stat[s] = statement_count;
        stat[f] = statement_count;
        return;
    };


    if(varNames.find(f) == varNames.end()) {
        clean_queues();
		cout << "Couldn't find " << f << endl;
        return;
    };



    queue<string> op_v1(op_value);
    while(op_v1.size() > ll)
        op_v1.pop();


    stack<string> op_v2;
    queue<string> op_v3;

    for(int i=0; i < ll; ++i) {
        op_v2.push(op_v1.front());
        op_v3.push(op_v1.front());
        op_v1.pop();
    };

    CudaSet *a;
    a = varNames.find(f)->second;
	
    if(a->mRecCount == 0) {
        CudaSet *c;
        c = new CudaSet(0,1);
        varNames[s] = c;
        clean_queues();
		cout << "SELECT " << s << " count : 0,  Mem " << getFreeMem() << endl;
        return;
    };

    cout << "SELECT " << s << " " << f << " " << getFreeMem() << endl;
    std::clock_t start1 = std::clock();

    // here we need to determine the column count and composition

    queue<string> op_v(op_value);
    queue<string> op_vx;
    set<string> field_names;
    map<string,string> aliases;
    string tt;
	

	//cout << "colsize " << a->columnNames.size() << endl;
	
    while(!op_v.empty()) {
        if(a->columnNames.find(op_v.front()) != a->columnNames.end()) {          
			tt = op_v.front();
			if(!op_v.empty()) {
				op_v.pop();
				if(!op_v.empty()) {
					if(a->columnNames.find(op_v.front()) == a->columnNames.end()) {
						if(aliases.count(tt) == 0) {
							aliases[tt] = op_v.front();				
						};	
					}
					else {
						if (!op_v.empty()) {
							while(a->columnNames.find(op_v.front()) == a->columnNames.end())
								op_v.pop();			
						};		
					}; 									
				};	
			};
		};	
		if(!op_v.empty())
			op_v.pop();
	};	
	
	op_v = op_value;
	while(!op_v.empty()) {
		if(a->columnNames.find(op_v.front()) != a->columnNames.end()) {
			field_names.insert(op_v.front());
		};	
		op_v.pop();
	};
	


    for (set<string>::iterator it=field_names.begin(); it!=field_names.end(); ++it)  {
        op_vx.push(*it);
    };
	
    // find out how many columns a new set will have
    queue<string> op_t(op_type);
    int_type col_count = 0;

    for(int i=0; !op_t.empty(); ++i, op_t.pop())
        if((op_t.front()).compare("emit sel_name") == 0)
            col_count++;

    CudaSet *b, *c;

    curr_segment = 10000000;
	if(a->segCount <= 1)
		setSegments(a, op_vx);
    allocColumns(a, op_vx);
	
    unsigned int cycle_count;
    if(!a->prm.empty())
        cycle_count = varNames[setMap[op_value.front()]]->segCount;
    else
        cycle_count = a->segCount;

    unsigned long long int ol_count = a->mRecCount;
	unsigned int cnt;
    //varNames[setMap[op_value.front()]]->oldRecCount = varNames[setMap[op_value.front()]]->mRecCount;
    a->oldRecCount = a->mRecCount;
    b = new CudaSet(0, col_count);
    bool b_set = 0, c_set = 0;

    unsigned int long long tmp_size = a->mRecCount;
    if(a->segCount > 1)
        tmp_size = a->maxRecs;		
    
    vector<thrust::device_vector<int_type> > distinct_val; //keeps array of DISTINCT values for every key
    vector<thrust::device_vector<int_type> > distinct_hash; //keeps array of DISTINCT values for every key
    vector<thrust::device_vector<int_type> > distinct_tmp;

    for(unsigned int i = 0; i < distinct_cnt; i++) {
        distinct_tmp.push_back(thrust::device_vector<int_type>(tmp_size));
        distinct_val.push_back(thrust::device_vector<int_type>());
        distinct_hash.push_back(thrust::device_vector<int_type>());
    };
	

// find out how many string columns we have. Add int_type columns to store string hashes for sort/groupby ops.
    stack<string> op_s = op_v2;
    int_col_count = a->d_columns_int.size();

    while(!op_s.empty()) {
        int colInd = (a->columnNames).find(op_s.top())->second;		
        if (a->type[colInd] == 2) {
            a->d_columns_int.push_back(thrust::device_vector<int_type>());
        };
        op_s.pop();
    };
	

    unsigned int s_cnt;
    bool one_liner;

    for(unsigned int i = 0; i < cycle_count; i++) {          // MAIN CYCLE
        cout << "segment " << i << " select mem " << getFreeMem() << '\xd';
		
        cnt = 0;
        copyColumns(a, op_vx, i, cnt);		
        reset_offsets();
        op_s = op_v2;
        s_cnt = 0;
		

        while(!op_s.empty()) {

            int colInd = (a->columnNames).find(op_s.top())->second;
            if (a->type[colInd] == 2) {
                a->d_columns_int[int_col_count + s_cnt].resize(0);
                a->add_hashed_strings(op_s.top(), i, int_col_count + s_cnt);
                s_cnt++;
            };
            op_s.pop();
        };

        if(a->mRecCount) {
            if (ll != 0) {
                order_inplace(a,op_v2,field_names);
                a->GroupBy(op_v2, int_col_count);
            };			
						
            select(op_type,op_value,op_nums, op_nums_f,a,b, distinct_tmp, one_liner);			
	
            if(!b_set) {
                for ( map<string,int>::iterator it=b->columnNames.begin() ; it != b->columnNames.end(); ++it )
                    setMap[(*it).first] = s;
                b_set = 1;
                unsigned int old_cnt = b->mRecCount;
                b->mRecCount = 0;
                b->resize(varNames[setMap[op_vx.front()]]->maxRecs);
                b->mRecCount = old_cnt;
            };			

            if (!c_set) {
                c = new CudaSet(0, col_count);
                create_c(c,b);
                c_set = 1;
            };

            if (ll != 0 && cycle_count > 1  ) {
                add(c,b,op_v3, aliases, distinct_tmp, distinct_val, distinct_hash, a);
            }
            else {
                //copy b to c
                unsigned int c_offset = c->mRecCount;
                c->resize(b->mRecCount);
                for(unsigned int j=0; j < b->mColumnCount; j++) {
                    if (b->type[j] == 0) {
                        thrust::copy(b->d_columns_int[b->type_index[j]].begin(), b->d_columns_int[b->type_index[j]].begin() + b->mRecCount, c->h_columns_int[c->type_index[j]].begin() + c_offset);
                    }
                    else if (b->type[j] == 1) {
                        thrust::copy(b->d_columns_float[b->type_index[j]].begin(), b->d_columns_float[b->type_index[j]].begin() + b->mRecCount, c->h_columns_float[c->type_index[j]].begin() + c_offset);
                    }
                    else {
                        cudaMemcpy((void*)(thrust::raw_pointer_cast(c->h_columns_char[c->type_index[j]] + b->char_size[b->type_index[j]]*c_offset)), (void*)thrust::raw_pointer_cast(b->d_columns_char[b->type_index[j]]),
                                   b->char_size[b->type_index[j]] * b->mRecCount, cudaMemcpyDeviceToHost);
                    };
                };

            };
        };
    };

    a->mRecCount = ol_count;
    a->mRecCount = a->oldRecCount;
    a->deAllocOnDevice();
    b->deAllocOnDevice();

    if (ll != 0) {
        count_avg(c, distinct_hash);
    }
    else {
        if(one_liner) {
            count_simple(c);
        };
    };

    reset_offsets();
    c->maxRecs = c->mRecCount;
    c->name = s;
    c->keep = 1;

    for ( map<string,int>::iterator it=c->columnNames.begin() ; it != c->columnNames.end(); ++it ) {
        setMap[(*it).first] = s;
    };

    cout << endl << "final select " << c->mRecCount << endl;
    clean_queues();

    varNames[s] = c;
    b->free();
    varNames[s]->keep = 1;

    if(stat[s] == statement_count) {
        varNames[s]->free();
        varNames.erase(s);
    };

    if(stat[f] == statement_count && a->keep == 0) {
        a->free();
        varNames.erase(f);
    };
    std::cout<< "select time " <<  ( ( std::clock() - start1 ) / (double)CLOCKS_PER_SEC ) <<'\n';
}


void emit_filter(char *s, char *f, int e)
{
    statement_count++;
    if (scan_state == 0) {
        if (stat.find(f) == stat.end()) {
            cout << "Filter : couldn't find variable " << f << endl;
            exit(1);
        };
        stat[s] = statement_count;
        stat[f] = statement_count;
        clean_queues();
        return;
    };

    if(varNames.find(f) == varNames.end()) {
        clean_queues();
        return;
    };

    CudaSet *a, *b;

    a = varNames.find(f)->second;
    a->name = f;
    std::clock_t start1 = std::clock();

    if(a->mRecCount == 0) {
        b = new CudaSet(0,1);
    }
    else {
        cout << "FILTER " << s << " " << f << " " << getFreeMem() << endl;

        b = a->copyDeviceStruct();
        b->name = s;
		b->sorted_fields = a->sorted_fields;

        unsigned int cycle_count = 1, cnt = 0;
        allocColumns(a, op_value);
		
        varNames[setMap[op_value.front()]]->oldRecCount = varNames[setMap[op_value.front()]]->mRecCount;

        if(a->segCount != 1)
            cycle_count = varNames[setMap[op_value.front()]]->segCount;

        oldCount = a->mRecCount;
        thrust::device_vector<unsigned int> p(a->maxRecs);

        for(unsigned int i = 0; i < cycle_count; i++) {
            map_check = zone_map_check(op_type,op_value,op_nums, op_nums_f, a, i);
			cout << "MAP CHECK segment " << i << " " << map_check <<  '\xd';
            reset_offsets();
            if(map_check == 'R') {
                copyColumns(a, op_value, i, cnt);
			    filter(op_type,op_value,op_nums, op_nums_f,a, b, i, p);			
            }
            else  {
                setPrm(a,b,map_check,i);
            };			
        };
        a->mRecCount = oldCount;
        varNames[setMap[op_value.front()]]->mRecCount = varNames[setMap[op_value.front()]]->oldRecCount;        
        a->deAllocOnDevice();
		cout << endl << "filter is finished " << b->mRecCount << " " << getFreeMem()  << endl;
    };

    clean_queues();
	
    if (varNames.count(s) > 0)
        varNames[s]->free();
    varNames[s] = b;
	
    if(stat[s] == statement_count) {
        b->free();
        varNames.erase(s);
    };
    if(stat[f] == statement_count && !a->keep) {
        //a->free();
        //varNames.erase(f);
    };
    std::cout<< "filter time " <<  ( ( std::clock() - start1 ) / (double)CLOCKS_PER_SEC ) << " " << getFreeMem() << '\n';
}

void emit_store(char *s, char *f, char* sep)
{
    statement_count++;
    if (scan_state == 0) {
        if (stat.find(s) == stat.end()) {
            cout << "Store : couldn't find variable " << s << endl;
            exit(1);
        };
        stat[s] = statement_count;
        return;
    };

    if(varNames.find(s) == varNames.end())
        return;

    CudaSet* a = varNames.find(s)->second;
    cout << "STORE: " << s << " " << f << " " << sep << endl;

    int limit = 0;
    if(!op_nums.empty()) {
        limit = op_nums.front();
        op_nums.pop();
    };

    a->Store(f,sep, limit, 0);

    if(stat[s] == statement_count  && a->keep == 0) {
        a->free();
        varNames.erase(s);
    };
};


void emit_store_binary(char *s, char *f)
{
    statement_count++;
    if (scan_state == 0) {
        if (stat.find(s) == stat.end()) {
            cout << "Store : couldn't find variable " << s << endl;
            exit(1);
        };
        stat[s] = statement_count;
        return;
    };

    if(varNames.find(s) == varNames.end())
        return;

    CudaSet* a = varNames.find(s)->second;

    if(stat[f] == statement_count)
        a->deAllocOnDevice();

    printf("STORE: %s %s \n", s, f);

    int limit = 0;
    if(!op_nums.empty()) {
        limit = op_nums.front();
        op_nums.pop();
    };
    total_count = 0;
    total_segments = 0;
    
	if(fact_file_loaded) {
		a->Store(f,"", limit, 1);	
	}
	else { 
		while(!fact_file_loaded)	{
			cout << "LOADING " << f_file << " mem: " << getFreeMem() << endl;
			if(a->text_source)
				fact_file_loaded = a->LoadBigFile(f_file.c_str(), separator.c_str());
			a->Store(f,"", limit, 1);
		};
	};	

    if(stat[f] == statement_count && !a->keep) {
        a->free();
        varNames.erase(s);
    };

};


void emit_load_binary(char *s, char *f, int d)
{
    statement_count++;
    if (scan_state == 0) {
        stat[s] = statement_count;
        return;
    };

    printf("BINARY LOAD: %s %s \n", s, f);

    CudaSet *a;
    unsigned int segCount, maxRecs;
    char f1[100];
    strcpy(f1, f);
    strcat(f1,".");
    char col_pos[3];
    itoaa(cols.front(),col_pos);
    strcat(f1,col_pos);
    strcat(f1,".header");

    FILE* ff = fopen(f1, "rb");
	if(ff == NULL) {
	    cout << "Couldn't open file " << f1 << endl;
		exit(0);
	};	
    fread((char *)&totalRecs, 8, 1, ff);
    fread((char *)&segCount, 4, 1, ff);
    fread((char *)&maxRecs, 4, 1, ff);
    fclose(ff);

	cout << "Reading " << totalRecs << " records" << endl;
    queue<string> names(namevars);
    while(!names.empty()) {
        setMap[names.front()] = s;
        names.pop();
    };

    a = new CudaSet(namevars, typevars, sizevars, cols,totalRecs, f);
    a->segCount = segCount;
    a->maxRecs = maxRecs;
    a->keep = 1;
    varNames[s] = a;

    if(stat[s] == statement_count )  {
        a->free();
        varNames.erase(s);
    };
}


void emit_load(char *s, char *f, int d, char* sep)
{
    statement_count++;
    if (scan_state == 0) {
        stat[s] = statement_count;
        return;
    };

    printf("LOAD: %s %s %d  %s \n", s, f, d, sep);

    CudaSet *a;

    a = new CudaSet(namevars, typevars, sizevars, cols, process_count);
    a->mRecCount = 0;
    a->resize(process_count);
    a->keep = true;
    a->not_compressed = 1;

    string separator1(sep);
    separator = separator1;
    string ff(f);
    f_file = ff;
    a->maxRecs = a->mRecCount;
    a->segCount = 0;
    varNames[s] = a;
	fact_file_loaded = 0;

    if(stat[s] == statement_count)  {
        a->free();
        varNames.erase(s);
    };
}



void yyerror(char *s, ...)
{
    extern int yylineno;
    va_list ap;
    va_start(ap, s);

    fprintf(stderr, "%d: error: ", yylineno);
    vfprintf(stderr, s, ap);
    fprintf(stderr, "\n");
}

void clean_queues()
{
    while(!op_type.empty()) op_type.pop();
    while(!op_value.empty()) op_value.pop();
    while(!op_join.empty()) op_join.pop();
    while(!op_nums.empty()) op_nums.pop();
    while(!op_nums_f.empty()) op_nums_f.pop();
    while(!j_col_count.empty()) j_col_count.pop();
    while(!namevars.empty()) namevars.pop();
    while(!typevars.empty()) typevars.pop();
    while(!sizevars.empty()) sizevars.pop();
    while(!cols.empty()) cols.pop();
	while(!op_sort.empty()) op_sort.pop();
	
	

    sel_count = 0;
    join_cnt = 0;
    join_col_cnt = 0;
    distinct_cnt = 0;
    reset_offsets();
	join_tab_cnt = 0;
	tab_cnt = 0;
	join_and_cnt.clear();
}



int main(int ac, char **av)
{
    extern FILE *yyin;
    //cudaDeviceProp deviceProp;

    //cudaGetDeviceProperties(&deviceProp, 0);
    //if (!deviceProp.canMapHostMemory)
    //    cout << "Device 0 cannot map host memory" << endl;

    //cudaSetDeviceFlags(cudaDeviceMapHost);
	//context = CreateCudaDevice(0);
	context = CreateCudaDevice(0, av, true);
    AllocPtr standardAlloc(new CudaAllocSimple(&context->Device()));
    context->SetAllocator(standardAlloc);
	
    cudppCreate(&theCudpp);
	
    /*long long int r30 = RAND_MAX*rand()+rand();
    long long int s30 = RAND_MAX*rand()+rand();
    long long int t4  = rand() & 0xf;

    hash_seed = (r30 << 34) + (s30 << 4) + t4;
	*/
	hash_seed = 100;

    if (ac == 1) {
        cout << "Usage : alenka -l process_count script.sql" << endl;
        exit(1);
    };

    if(strcmp(av[1],"-l") == 0) {
        process_count = atoff(av[2]);
        cout << "Process count = " << process_count << endl;
    }
    else {
        process_count = 6200000;
        cout << "Process count = 6200000 " << endl;
    };

    if((yyin = fopen(av[ac-1], "r")) == NULL) {
        perror(av[ac-1]);
        exit(1);
    };

    if(yyparse()) {
        printf("SQL scan parse failed\n");
        exit(1);
    };

    scan_state = 1;

    std::clock_t start1 = std::clock();
    statement_count = 0;
    clean_queues();

    if(ac > 1 && (yyin = fopen(av[ac-1], "r")) == NULL) {
        perror(av[1]);
        exit(1);
    }

    PROC_FLUSH_BUF ( yyin );
    statement_count = 0;

    if(!yyparse())
        cout << "SQL scan parse worked" << endl;
    else
        cout << "SQL scan parse failed" << endl;
		
	std::cout<< "tot disk time " <<  (( tot ) / (double)CLOCKS_PER_SEC ) <<'\n';


    if(alloced_sz)
        cudaFree(alloced_tmp);

    fclose(yyin);
    std::cout<< "cycle time " <<  ( ( std::clock() - start1 ) / (double)CLOCKS_PER_SEC ) <<'\n';
    cudppDestroy(theCudpp);

}


