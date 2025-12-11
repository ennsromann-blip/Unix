#include <filesystem>
#include <iostream>
#include <fstream>
#include <unordered_map>
#include <stdio.h>
#include <unistd.h>
#include <openssl/sha.h>

namespace fs = std::filesystem;

std::string getSHA1(const fs::path& path)
{
    unsigned char hash[SHA_DIGEST_LENGTH];
    SHA_CTX sha;
    if (SHA1_Init(&sha) != 1) return "";

    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) return "";

    char buffer[8192];
    while (file.read(buffer, sizeof(buffer))){
        SHA1_Update(&sha, (unsigned char*)buffer, file.gcount());
    }

    if (file.gcount() > 0) {
        SHA1_Update(&sha, (unsigned char*)buffer, file.gcount());
    }

    if (SHA1_Final(hash, &sha) != 1) return "";
    
    char hex[2 * SHA_DIGEST_LENGTH + 1];
    for (int i = 0; i < SHA_DIGEST_LENGTH; i++) {
        std::sprintf(hex + i * 2, "%02x", hash[i]);
    }

    return std::string(hex, 40);
}

bool replace_hash_to_link(const fs::path& original, const fs::path& duplicate)
{
    if (!fs::remove(duplicate)) {
        std::cerr << "Failed to remove duplicate file" << "\n";
        return false;
    }

    if (::link(original.c_str(), duplicate.c_str()) == 0) {
        std::cout << "Replaced with hard link" << "\n";
        return true;
    }

    std::cerr << "Failed to create hard link from " << original << " to "<< duplicate << "\n";
    return false;
}


int main(int argc, char* argv[]) {
    
    if (argc != 2){
        std::cerr << "Error: the directory path is not specified" << "\n";
        std::cerr << "Usage: " << argv[0] << " <directory_path>" << "\n";
        return 1; 
    }

    std::string target_directory = argv[1];

    if (!fs::is_directory(target_directory)) {
        std::cerr << "Error: The specified path '" << target_directory << "' is not a directory or does not exist." << "\n";
        return 1;
    }

    std::unordered_map<std::string, fs::path> hash_map;


    for (const auto& p : fs::recursive_directory_iterator(target_directory)) {

        if (!fs::is_regular_file(p)) continue;

        fs::path current_path = p.path();

        std::string hash = getSHA1(current_path);
        if (hash.empty()) continue;

        if (hash_map.find(hash) != hash_map.end()) {
            std::cout << "Duplicate " << current_path << " => " << hash_map[hash] << "\n";
            replace_hash_to_link(hash_map[hash], current_path);
        }
        else {
            hash_map[hash] = current_path;
        }
    }

    return 0;
}

