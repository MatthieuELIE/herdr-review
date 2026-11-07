globals = { 'vim' }
std = 'luajit'

files['tests'] = {
    read_globals = { 'describe', 'it' },
}
