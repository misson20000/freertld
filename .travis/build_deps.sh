if [[ ! -d unicorn/.git ]]; then
		git clone https://github.com/misson20000/unicorn.git -b all_features
fi
gem install bundler -v 1.16.1
cd unicorn
git fetch origin all_features
git reset --hard origin/all_features
./make.sh && sudo ./make.sh install && cd bindings/ruby/unicorn_gem && rake install && cd ../../../../
bundle install
