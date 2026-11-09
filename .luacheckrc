globals = { 'vim' }
std = 'luajit'
exclude_files = { '.project/**', '.claude/**' }

files['tests'] = {
    read_globals = { 'describe', 'it', 'before_each', 'after_each' },
}
